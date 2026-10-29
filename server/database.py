import os
import sqlite3
from pathlib import Path
from typing import Optional

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


def _migrate_items_transaction_id(conn: sqlite3.Connection) -> None:
    """物品和账单互相关联 + 物品分类直连 categories 表。

    - transaction_id / sold_transaction_id：物品 ↔ 账单
    - category_id：物品 ↔ 分类，彻底消除"两套分类"的问题
    """
    columns = _column_names(conn, "items")
    if "transaction_id" not in columns:
        conn.execute("ALTER TABLE items ADD COLUMN transaction_id INTEGER")
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_items_transaction_id ON items (transaction_id)"
        )
    if "sold_transaction_id" not in columns:
        conn.execute("ALTER TABLE items ADD COLUMN sold_transaction_id INTEGER")
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_items_sold_transaction_id ON items (sold_transaction_id)"
        )
    if "sold_amount_cents" not in columns:
        conn.execute("ALTER TABLE items ADD COLUMN sold_amount_cents INTEGER")
    if "sold_date" not in columns:
        conn.execute("ALTER TABLE items ADD COLUMN sold_date TEXT")
    if "category_id" not in columns:
        conn.execute("ALTER TABLE items ADD COLUMN category_id INTEGER")
        # 用物品原有的 category 文本回填 category_id
        _backfill_item_category_ids(conn)


# 物品关键词 → 通用分类名（按优先级排序）
# 匹配方向：物品名/物品老category文本中的关键词 → 用户实际分类名
_KEYWORD_TO_CATEGORY = [
    # (关键词, 通用分类名)
    ("数码", "购物"), ("电子", "购物"), ("手机", "购物"), ("电脑", "购物"),
    ("笔记本", "购物"), ("平板", "购物"), ("耳机", "购物"), ("相机", "购物"),
    ("家电", "购物"), ("电器", "购物"), ("冰箱", "购物"), ("洗衣机", "购物"),
    ("空调", "购物"), ("电视", "购物"), ("微波炉", "购物"), ("吸尘器", "购物"),
    ("家具", "购物"), ("家居", "购物"), ("沙发", "购物"), ("衣柜", "购物"),
    ("鞋", "购物"), ("服装", "购物"), ("衣服", "购物"), ("包", "购物"),
    ("汽车", "交通"), ("电动车", "交通"), ("自行车", "交通"), ("加油", "交通"),
    ("停车", "交通"), ("摩托", "交通"),
    ("运动", "娱乐"), ("户外", "娱乐"), ("健身", "娱乐"), ("打球", "娱乐"),
    ("跑步", "娱乐"), ("骑行", "娱乐"), ("露营", "娱乐"),
    ("药", "医疗"), ("看病", "医疗"), ("体检", "医疗"),
    ("培训", "教育"), ("学费", "教育"), ("课程", "教育"), ("书本", "教育"),
    ("房租", "住房"), ("装修", "住房"), ("水电", "住房"), ("物业", "住房"),
]


def _match_category_for_item(name: str, old_category: str, cats: dict, fallback: Optional[int]) -> Optional[int]:
    """给物品匹配一个合理的 expense 分类。

    匹配优先级：
    1) 物品名或老category文本精确命中用户分类名 → 直接用
    2) 关键词命中通用分类名 → 用用户分类中最接近的
    3) 兜底第一个 expense 分类
    """
    # 把物品名和老 category 合并一起搜
    haystack = f"{name or ''} {old_category or ''}"
    haystack = haystack.strip()
    if not haystack:
        return fallback

    # 1) 精确/包含匹配：物品名直接在用户分类名里出现
    for cat_name, cat_id in cats.items():
        if cat_name in haystack or haystack in cat_name:
            return cat_id

    # 2) 关键词匹配：物品关键词 → 通用分类名 → 找用户里同名的
    for keyword, suggest_name in _KEYWORD_TO_CATEGORY:
        if keyword in haystack:
            # 精确找
            if suggest_name in cats:
                return cats[suggest_name]
            # 模糊：用户分类名包含 suggest_name 或 suggest_name 包含用户分类名
            for cat_name, cat_id in cats.items():
                if cat_name in suggest_name or suggest_name in cat_name:
                    return cat_id

    # 3) 兜底
    return fallback


def _backfill_item_category_ids(conn: sqlite3.Connection) -> None:
    """确保所有物品都有合理的 category_id。

    - 新物品（category_id 为空）：匹配填入
    - 已有 category_id 但可能不准确的物品：如果能更准确匹配则修正
    """
    users = conn.execute("SELECT DISTINCT user_id FROM items").fetchall()
    total_filled = 0
    total_fixed = 0
    for (uid,) in users:
        items = conn.execute(
            "SELECT id, name, category, category_id FROM items WHERE user_id = ?",
            (uid,),
        ).fetchall()
        if not items:
            continue
        # 该用户的 expense 分类
        cats = {
            row["name"]: row["id"]
            for row in conn.execute(
                "SELECT id, name FROM categories WHERE user_id = ? AND type = 'expense'",
                (uid,),
            ).fetchall()
        }
        if not cats:
            continue
        # 兜底：第一个 expense 分类
        fallback = min(cats.values())

        for item in items:
            item_id = item["id"]
            current = item["category_id"]
            target = _match_category_for_item(
                item["name"], item["category"] or "", cats, fallback
            )
            if target is None:
                continue
            if current is None:
                conn.execute(
                    "UPDATE items SET category_id = ? WHERE id = ?",
                    (target, item_id),
                )
                total_filled += 1
            elif current != target:
                conn.execute(
                    "UPDATE items SET category_id = ? WHERE id = ?",
                    (target, item_id),
                )
                total_fixed += 1
    conn.commit()
    if total_filled or total_fixed:
        print(f"  [migrate] 物品分类: 新填 {total_filled} 条, 修正 {total_fixed} 条")


def _sync_item_expense_transactions(conn: sqlite3.Connection) -> None:
    """老物品迁移后，关联的 expense 账单 category_id 可能与 items.category_id 不一致。

    只同步 expense 类型的关联账单（external_id = 'item_{id}'），
    income 类型的出售账单（'item_{id}_sold'）保持不动——它用的是独立的收入分类。
    """
    # 只扫描 source='item' 且 category_id 可能需要同步的
    rows = conn.execute("""
        SELECT i.id, i.category_id, i.user_id
        FROM items i
        WHERE i.category_id IS NOT NULL
    """).fetchall()
    updated = 0
    for item in rows:
        item_id = item["id"]
        cat_id = item["category_id"]
        uid = item["user_id"]
        # 更新 expense 账单（external_id 精确匹配 item_{id}，不是 item_{id}_sold）
        cursor = conn.execute("""
            UPDATE transactions
            SET category_id = ?
            WHERE source = 'item'
              AND user_id = ?
              AND type = 'expense'
              AND external_id = ?
              AND category_id != ?
        """, (cat_id, uid, f"item_{item_id}", cat_id))
        updated += cursor.rowcount
    conn.commit()
    if updated:
        print(f"  [migrate] 同步了 {updated} 条物品关联的 expense 账单 category_id")


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
        _migrate_items_transaction_id(conn)
        _backfill_item_category_ids(conn)
        _sync_item_expense_transactions(conn)
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
