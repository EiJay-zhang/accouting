import os
import sqlite3
import tempfile
import unittest
from pathlib import Path

_fd, _DB = tempfile.mkstemp(suffix=".db")
os.close(_fd)
os.environ["DATABASE_PATH"] = _DB

from fastapi import HTTPException

from auth import register_account, require_user
from database import get_connection, init_db
from main import (
    BudgetIn,
    CreateTransactionIn,
    category_report,
    create_transaction,
    transaction_summary,
    upsert_budget,
)
from money import cents_to_yuan, yuan_to_cents


class LedgerRulesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        init_db()
        session = register_account("ledger", "secret1", "测试")
        cls.user_id = session["user"]["id"]
        with get_connection() as conn:
            row = conn.execute(
                """
                SELECT id FROM categories
                WHERE user_id = ? AND type = 'expense'
                ORDER BY id LIMIT 1
                """,
                (cls.user_id,),
            ).fetchone()
        cls.category_id = int(row["id"])

    def test_cents_do_not_drift(self):
        self.assertEqual(yuan_to_cents(0.1) + yuan_to_cents(0.2), 30)
        self.assertEqual(cents_to_yuan(30), 0.3)

    def test_summary_uses_cents(self):
        create_transaction(
            CreateTransactionIn(
                title="一毛",
                category_id=self.category_id,
                amount=0.1,
                type="expense",
                date="2026-03-02",
            ),
            user_id=self.user_id,
        )
        create_transaction(
            CreateTransactionIn(
                title="两毛",
                category_id=self.category_id,
                amount=0.2,
                type="expense",
                date="2026-03-03",
            ),
            user_id=self.user_id,
        )
        summary = transaction_summary(year=2026, month=3, user_id=self.user_id)
        self.assertEqual(summary.expense, 0.3)
        self.assertEqual(summary.total, -0.3)

    def test_session_expires(self):
        session = register_account("expire", "secret1", "过期")
        token = session["token"]
        with get_connection() as conn:
            conn.execute(
                "UPDATE sessions SET expires_at = ? WHERE token = ?",
                ("2020-01-01T00:00:00", token),
            )
            conn.commit()
        with self.assertRaises(HTTPException) as caught:
            require_user(authorization=f"Bearer {token}")
        self.assertEqual(caught.exception.status_code, 401)
        self.assertIn("过期", caught.exception.detail)

    def test_week_and_year_budgets_are_independent(self):
        upsert_budget(
            BudgetIn(
                category_id=self.category_id,
                year=2026,
                month=1,
                amount=100,
                scope="month",
            ),
            user_id=self.user_id,
        )
        upsert_budget(
            BudgetIn(
                category_id=self.category_id,
                year=2026,
                month=1,
                amount=500,
                scope="year",
            ),
            user_id=self.user_id,
        )
        upsert_budget(
            BudgetIn(
                category_id=self.category_id,
                year=2026,
                month=1,
                amount=40,
                scope="week",
                anchor="2026-01-14",
            ),
            user_id=self.user_id,
        )
        month = category_report(
            period="month",
            year=2026,
            month=1,
            anchor=None,
            user_id=self.user_id,
        )
        year = category_report(
            period="year",
            year=2026,
            month=None,
            anchor=None,
            user_id=self.user_id,
        )
        week = category_report(
            period="week",
            year=None,
            month=None,
            anchor="2026-01-14",
            user_id=self.user_id,
        )
        month_budget = _budget(month, self.category_id)
        year_budget = _budget(year, self.category_id)
        week_budget = _budget(week, self.category_id)
        self.assertEqual(month_budget, 100)
        self.assertEqual(year_budget, 500)
        self.assertEqual(week_budget, 40)

    def test_existing_database_keeps_transactions(self):
        live = Path(__file__).resolve().parent / "account.db"
        if not live.exists():
            self.skipTest("没有本地账本")
        copy = tempfile.mktemp(suffix=".db")
        source = sqlite3.connect(f"file:{live}?mode=ro", uri=True)
        before = sqlite3.connect(copy)
        try:
            source.backup(before)
            count_before = before.execute(
                "SELECT COUNT(*) FROM transactions"
            ).fetchone()[0]
        finally:
            before.close()
            source.close()
        previous = os.environ["DATABASE_PATH"]
        os.environ["DATABASE_PATH"] = copy
        try:
            init_db()
            after = sqlite3.connect(copy)
            count_after = after.execute("SELECT COUNT(*) FROM transactions").fetchone()[0]
            missing = after.execute(
                "SELECT COUNT(*) FROM transactions WHERE amount_cents IS NULL"
            ).fetchone()[0]
            columns = {
                row[1] for row in after.execute("PRAGMA table_info(budgets)")
            }
            expired = after.execute(
                "SELECT COUNT(*) FROM sessions WHERE expires_at IS NULL OR expires_at = ''"
            ).fetchone()[0]
            after.close()
        finally:
            os.environ["DATABASE_PATH"] = previous
            for path in (copy, copy + "-wal", copy + "-shm"):
                if os.path.exists(path):
                    os.remove(path)
        self.assertEqual(count_after, count_before)
        self.assertEqual(missing, 0)
        self.assertIn("scope", columns)
        self.assertIn("amount_cents", columns)
        self.assertEqual(expired, 0)
        self.assertGreater(count_before, 0)


def _budget(report, category_id):
    for item in report.categories:
        if item.category.id == category_id:
            return item.budget
    return None


if __name__ == "__main__":
    unittest.main()
