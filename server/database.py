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


def init_db() -> Path:
    """创建表、索引和默认分类。不写入示例账单。"""
    path = get_db_path()
    with get_connection() as conn:
        conn.executescript(_read_sql("schema.sql"))
        _migrate_category_type(conn)
        _migrate_import_columns(conn)
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
        conn.commit()
        return conn.execute("SELECT COUNT(*) FROM transactions").fetchone()[0]
