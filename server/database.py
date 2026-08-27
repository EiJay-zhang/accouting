import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).parent / "account.db"

CATEGORIES = [
    ("餐饮", "🍜", "#FF9800"),
    ("交通", "🚇", "#2196F3"),
    ("购物", "🛍️", "#E91E63"),
    ("工资", "💰", "#4CAF50"),
    ("娱乐", "🎬", "#9C27B0"),
    ("医疗", "💊", "#F44336"),
    ("教育", "📚", "#3F51B5"),
    ("住房", "🏠", "#009688"),
]

SEED_TRANSACTIONS = [
    ("午餐·外卖", 1, 68.50, "expense", "2026-08-07"),
    ("地铁通勤", 2, 12.00, "expense", "2026-08-07"),
    ("8月薪资", 4, 18500.00, "income", "2026-08-05"),
    ("UNIQLO T恤×3", 3, 299.00, "expense", "2026-08-04"),
    ("电影票×2", 5, 88.00, "expense", "2026-08-03"),
    ("超市采购", 3, 245.00, "expense", "2026-08-02"),
    ("兼职收入", 4, 3200.00, "income", "2026-08-01"),
    ("早餐", 1, 15.00, "expense", "2026-08-01"),
]


def get_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with get_connection() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS categories (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                icon TEXT NOT NULL,
                color TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS transactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                category_id INTEGER NOT NULL,
                amount REAL NOT NULL,
                type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
                date TEXT NOT NULL,
                FOREIGN KEY (category_id) REFERENCES categories(id)
            );
            """
        )

        count = conn.execute("SELECT COUNT(*) FROM categories").fetchone()[0]
        if count == 0:
            conn.executemany(
                "INSERT INTO categories (name, icon, color) VALUES (?, ?, ?)",
                CATEGORIES,
            )

        tx_count = conn.execute("SELECT COUNT(*) FROM transactions").fetchone()[0]
        if tx_count == 0:
            conn.executemany(
                """
                INSERT INTO transactions (title, category_id, amount, type, date)
                VALUES (?, ?, ?, ?, ?)
                """,
                SEED_TRANSACTIONS,
            )

        conn.commit()
