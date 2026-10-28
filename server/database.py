import os
import sqlite3
from pathlib import Path

SQL_DIR = Path(__file__).parent / "sql"
DEFAULT_DB_PATH = Path(__file__).parent / "account.db"

# 没有账单、或收支笔数相同时，用名称判断默认类型。
_INCOME_CATEGORY_NAMES = {"工资", "奖金", "理财", "兼职", "红包"}


def get_db_path() -> Path:
    raw = os.environ.get("DATABASE_PATH", "").strip()
    if raw:
        return Path(raw).expanduser()
    return DEFAULT_DB_PATH


def _read_sql(name: str) -> str:
    return (SQL_DIR / name).read_text(encoding="utf-8")


def _sql_statements(script: str) -> list[str]:
    statements = []
    for chunk in script.split(";"):
        lines = [
            line
            for line in chunk.splitlines()
            if line.strip() and not line.strip().startswith("--")
        ]
        statement = "\n".join(lines).strip()
        if statement:
            statements.append(statement)
    return statements


def get_connection() -> sqlite3.Connection:
    path = get_db_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA busy_timeout = 5000")
    return conn


def _column_names(conn: sqlite3.Connection, table: str) -> set[str]:
    return {row["name"] for row in conn.execute(f"PRAGMA table_info({table})")}


def _primary_category_type(name: str, income_count: int, expense_count: int) -> str:
    if income_count > expense_count:
        return "income"
    if expense_count > income_count:
        return "expense"
    if name in _INCOME_CATEGORY_NAMES:
        return "income"
    return "expense"


def _migrate_category_type(conn: sqlite3.Connection) -> None:
    """给旧库补上分类的收支类型，并拆开同时用于收入和支出的分类。"""
    if "type" in _column_names(conn, "categories"):
        return

    previous_isolation = conn.isolation_level
    conn.isolation_level = None
    try:
        conn.execute("PRAGMA foreign_keys = OFF")
        conn.execute("BEGIN")
        try:
            for statement in _sql_statements(_read_sql("migrate_category_type.sql")):
                conn.execute(statement)

            originals = list(
                conn.execute("SELECT id, name, icon, color FROM categories")
            )
            for row in originals:
                usage = conn.execute(
                    """
                    SELECT type, COUNT(*) AS n
                    FROM transactions
                    WHERE category_id = ?
                    GROUP BY type
                    """,
                    (row["id"],),
                ).fetchall()
                counts = {item["type"]: item["n"] for item in usage if item["type"]}
                income_count = counts.get("income", 0)
                expense_count = counts.get("expense", 0)
                primary = _primary_category_type(
                    row["name"], income_count, expense_count
                )
                conn.execute(
                    "UPDATE categories SET type = ? WHERE id = ?",
                    (primary, row["id"]),
                )

                other = "expense" if primary == "income" else "income"
                if counts.get(other, 0) == 0:
                    continue

                cloned = conn.execute(
                    "SELECT id FROM categories WHERE name = ? AND type = ?",
                    (row["name"], other),
                ).fetchone()
                if cloned is None:
                    cursor = conn.execute(
                        """
                        INSERT INTO categories (name, icon, color, type)
                        VALUES (?, ?, ?, ?)
                        """,
                        (row["name"], row["icon"], row["color"], other),
                    )
                    cloned_id = cursor.lastrowid
                else:
                    cloned_id = cloned["id"]

                conn.execute(
                    """
                    UPDATE transactions
                    SET category_id = ?
                    WHERE category_id = ? AND type = ?
                    """,
                    (cloned_id, row["id"], other),
                )
            conn.execute("COMMIT")
        except Exception:
            conn.execute("ROLLBACK")
            raise
    finally:
        conn.execute("PRAGMA foreign_keys = ON")
        conn.isolation_level = previous_isolation


def _migrate_users(conn: sqlite3.Connection) -> None:
    """给旧库补上账号，并把分类改成按账号区分。"""
    if "user_id" not in _column_names(conn, "categories"):
        previous_isolation = conn.isolation_level
        conn.isolation_level = None
        try:
            conn.execute("PRAGMA foreign_keys = OFF")
            conn.execute("BEGIN")
            try:
                conn.execute(
                    """
                    CREATE TABLE categories_new (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        user_id INTEGER,
                        name TEXT NOT NULL,
                        icon TEXT NOT NULL,
                        color TEXT NOT NULL,
                        type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
                        UNIQUE (user_id, name, type),
                        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
                    )
                    """
                )
                conn.execute(
                    """
                    INSERT INTO categories_new (id, user_id, name, icon, color, type)
                    SELECT id, NULL, name, icon, color, type FROM categories
                    """
                )
                conn.execute("DROP TABLE categories")
                conn.execute("ALTER TABLE categories_new RENAME TO categories")
                conn.execute("COMMIT")
            except Exception:
                conn.execute("ROLLBACK")
                raise
        finally:
            conn.execute("PRAGMA foreign_keys = ON")
            conn.isolation_level = previous_isolation

    if "user_id" not in _column_names(conn, "transactions"):
        conn.execute("ALTER TABLE transactions ADD COLUMN user_id INTEGER")
    if "user_id" not in _column_names(conn, "chat_messages"):
        conn.execute("ALTER TABLE chat_messages ADD COLUMN user_id INTEGER")

    conn.execute("DROP INDEX IF EXISTS idx_transactions_import_key")
    conn.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_import_key
        ON transactions (user_id, source, external_id)
        WHERE external_id IS NOT NULL AND source IS NOT NULL
        """
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_categories_user_id ON categories (user_id)"
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions (user_id)"
    )
    conn.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_chat_messages_user_id
        ON chat_messages (user_id)
        """
    )


def _migrate_import_columns(conn: sqlite3.Connection) -> None:
    """给旧库补上账单来源和外部单号，用来避免重复导入。"""
    columns = _column_names(conn, "transactions")
    if "source" not in columns:
        conn.execute("ALTER TABLE transactions ADD COLUMN source TEXT")
    if "external_id" not in columns:
        conn.execute("ALTER TABLE transactions ADD COLUMN external_id TEXT")
    conn.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_import_key
        ON transactions (source, external_id)
        WHERE external_id IS NOT NULL AND source IS NOT NULL
        """
    )


def _migrate_sessions(conn: sqlite3.Connection) -> None:
    """登录令牌 30 天后失效。旧会话从创建时间起算。"""
    from datetime import datetime, timedelta

    if "expires_at" not in _column_names(conn, "sessions"):
        conn.execute("ALTER TABLE sessions ADD COLUMN expires_at TEXT")
    rows = conn.execute(
        """
        SELECT token, created_at
        FROM sessions
        WHERE expires_at IS NULL OR expires_at = ''
        """
    ).fetchall()
    for row in rows:
        created = datetime.fromisoformat(row["created_at"])
        expires = (created + timedelta(days=30)).isoformat(timespec="seconds")
        conn.execute(
            "UPDATE sessions SET expires_at = ? WHERE token = ?",
            (expires, row["token"]),
        )


def _migrate_amount_cents(conn: sqlite3.Connection) -> None:
    """把已有金额换成整数分，避免浮点相加出现分位误差。"""
    if "amount_cents" not in _column_names(conn, "transactions"):
        conn.execute("ALTER TABLE transactions ADD COLUMN amount_cents INTEGER")
    conn.execute(
        """
        UPDATE transactions
        SET amount_cents = CAST(ROUND(amount * 100) AS INTEGER)
        WHERE amount_cents IS NULL
        """
    )


def _migrate_budgets(conn: sqlite3.Connection) -> None:
    """月预算保留，并允许单独保存周预算和年预算。"""
    columns = _column_names(conn, "budgets")
    if "scope" in columns and "amount_cents" in columns:
        return
    previous_isolation = conn.isolation_level
    conn.isolation_level = None
    try:
        conn.execute("PRAGMA foreign_keys = OFF")
        conn.execute("BEGIN")
        try:
            conn.execute(
                """
                CREATE TABLE budgets_new (
                    category_id INTEGER NOT NULL,
                    scope TEXT NOT NULL CHECK (scope IN ('week', 'month', 'year')),
                    period_key TEXT NOT NULL,
                    amount_cents INTEGER NOT NULL CHECK (amount_cents > 0),
                    PRIMARY KEY (category_id, scope, period_key),
                    FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
                )
                """
            )
            if "year" in columns and "month" in columns and "amount" in columns:
                conn.execute(
                    """
                    INSERT INTO budgets_new (category_id, scope, period_key, amount_cents)
                    SELECT
                        category_id,
                        'month',
                        printf('%04d-%02d', year, month),
                        CAST(ROUND(amount * 100) AS INTEGER)
                    FROM budgets
                    WHERE amount > 0
                    """
                )
            conn.execute("DROP TABLE budgets")
            conn.execute("ALTER TABLE budgets_new RENAME TO budgets")
            conn.execute("COMMIT")
        except Exception:
            conn.execute("ROLLBACK")
            raise
    finally:
        conn.execute("PRAGMA foreign_keys = ON")
        conn.isolation_level = previous_isolation


def init_db() -> Path:
    """创建表、索引和默认分类。不写入示例账单。"""
    path = get_db_path()
    with get_connection() as conn:
        conn.executescript(_read_sql("schema.sql"))
        _migrate_category_type(conn)
        _migrate_import_columns(conn)
        _migrate_users(conn)
        _migrate_sessions(conn)
        _migrate_amount_cents(conn)
        _migrate_budgets(conn)
        conn.executescript(_read_sql("seed_categories.sql"))
        _seed_default_tags(conn)
        conn.execute("PRAGMA journal_mode = WAL")
        conn.commit()
    return path


def _seed_default_tags(conn: sqlite3.Connection) -> None:
    """标签表为空时写入一套常用标签。之后用户删改不会被重新写回。"""
    existing = conn.execute("SELECT COUNT(*) FROM tags").fetchone()[0]
    if existing:
        return
    conn.executescript(_read_sql("seed_tags.sql"))


def seed_demo() -> int:
    """交易表为空时写入示例账单，返回写入条数。"""
    with get_connection() as conn:
        existing = conn.execute("SELECT COUNT(*) FROM transactions").fetchone()[0]
        if existing:
            return 0
        conn.executescript(_read_sql("seed_demo.sql"))
        conn.execute(
            """
            UPDATE transactions
            SET amount_cents = CAST(ROUND(amount * 100) AS INTEGER)
            WHERE amount_cents IS NULL
            """
        )
        conn.commit()
        return conn.execute("SELECT COUNT(*) FROM transactions").fetchone()[0]
