import io
import os
import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import auth
import wechat

_fd, _DB = tempfile.mkstemp(suffix=".db")
os.close(_fd)
os.environ["DATABASE_PATH"] = _DB

from fastapi import HTTPException
from openpyxl import load_workbook

from auth import delete_self, login_with_wechat, register_account, require_user
from database import get_connection, init_db
from main import (
    BudgetIn,
    CreateTransactionIn,
    category_report,
    create_transaction,
    export_transactions_xlsx,
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


class AccountLifecycleTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        init_db()

    def _expense_category(self, user_id: int) -> int:
        with get_connection() as conn:
            row = conn.execute(
                """
                SELECT id FROM categories
                WHERE user_id = ? AND type = 'expense'
                ORDER BY id LIMIT 1
                """,
                (user_id,),
            ).fetchone()
        return int(row["id"])

    def test_registration_requires_invite_code(self):
        os.environ["REGISTER_INVITE_CODE"] = "invite-123"
        try:
            with self.assertRaises(HTTPException) as caught:
                register_account("invite_bad", "secret1", None, "wrong")
            self.assertEqual(caught.exception.status_code, 403)
            session = register_account("invite_ok", "secret1", None, "invite-123")
            self.assertIn("token", session)
        finally:
            os.environ.pop("REGISTER_INVITE_CODE", None)

    def test_registration_can_be_closed(self):
        os.environ["REGISTER_ENABLED"] = "false"
        try:
            with self.assertRaises(HTTPException) as caught:
                register_account("closed_user", "secret1", None)
            self.assertEqual(caught.exception.status_code, 403)
            self.assertEqual(caught.exception.detail, "注册已关闭")
        finally:
            os.environ.pop("REGISTER_ENABLED", None)

    def test_delete_self_removes_all_data(self):
        session = register_account("bye_user", "secret1", None)
        user_id = int(session["user"]["id"])
        token = session["token"]
        create_transaction(
            CreateTransactionIn(
                title="待删除",
                category_id=self._expense_category(user_id),
                amount=12.5,
                type="expense",
                date="2026-03-10",
            ),
            user_id=user_id,
        )

        delete_self(user_id)

        with get_connection() as conn:
            for table, column in (
                ("users", "id"),
                ("sessions", "user_id"),
                ("categories", "user_id"),
                ("transactions", "user_id"),
                ("items", "user_id"),
                ("chat_messages", "user_id"),
            ):
                count = conn.execute(
                    f"SELECT COUNT(*) FROM {table} WHERE {column} = ?",
                    (user_id,),
                ).fetchone()[0]
                self.assertEqual(count, 0, f"{table} 仍有残留数据")
        with self.assertRaises(HTTPException) as caught:
            require_user(authorization=f"Bearer {token}")
        self.assertEqual(caught.exception.status_code, 401)

    def test_export_xlsx(self):
        session = register_account("xlsx_user", "secret1", None)
        user_id = int(session["user"]["id"])
        create_transaction(
            CreateTransactionIn(
                title="导出测试",
                category_id=self._expense_category(user_id),
                amount=9.9,
                type="expense",
                date="2026-03-11",
            ),
            user_id=user_id,
        )

        response = export_transactions_xlsx(user_id=user_id)

        self.assertEqual(response.status_code, 200)
        workbook = load_workbook(io.BytesIO(response.body))
        sheet = workbook.active
        self.assertEqual(
            [cell.value for cell in sheet[1]],
            ["日期", "类型", "分类", "标题", "金额", "标签"],
        )
        self.assertEqual(sheet.max_row, 2)
        self.assertEqual(sheet["D2"].value, "导出测试")
        self.assertAlmostEqual(sheet["E2"].value, 9.9)


class _FakeWechatResponse:
    def __init__(self, payload):
        self._payload = payload

    def raise_for_status(self):
        return None

    def json(self):
        return self._payload


class WechatLoginTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        init_db()

    def test_requires_configuration(self):
        with patch.dict(os.environ, {"WX_APPID": "", "WX_SECRET": ""}):
            with self.assertRaises(HTTPException) as caught:
                login_with_wechat("any-code")
        self.assertEqual(caught.exception.status_code, 503)

    def test_creates_and_reuses_user(self):
        payload = {"openid": "openid-test-001", "session_key": "should-not-leak"}
        with patch.dict(
            os.environ, {"WX_APPID": "wx-test", "WX_SECRET": "secret"}
        ), patch.object(
            wechat.httpx, "get", return_value=_FakeWechatResponse(payload)
        ):
            first = login_with_wechat("code-1")
            second = login_with_wechat("code-2")

        self.assertEqual(first["user"]["id"], second["user"]["id"])
        self.assertEqual(
            require_user(authorization=f"Bearer {first['token']}"),
            first["user"]["id"],
        )
        with get_connection() as conn:
            user = conn.execute(
                "SELECT wx_openid FROM users WHERE id = ?",
                (first["user"]["id"],),
            ).fetchone()
            category_count = conn.execute(
                "SELECT COUNT(*) FROM categories WHERE user_id = ?",
                (first["user"]["id"],),
            ).fetchone()[0]
        self.assertEqual(user["wx_openid"], "openid-test-001")
        self.assertGreater(category_count, 0)

    def test_rejects_invalid_code(self):
        with patch.dict(
            os.environ, {"WX_APPID": "wx-test", "WX_SECRET": "secret"}
        ), patch.object(
            wechat.httpx,
            "get",
            return_value=_FakeWechatResponse(
                {"errcode": 40029, "errmsg": "invalid code"}
            ),
        ):
            with self.assertRaises(HTTPException) as caught:
                login_with_wechat("bad-code")
        self.assertEqual(caught.exception.status_code, 401)

    def test_auth_status_reports_wechat_configuration(self):
        with patch.dict(os.environ, {"WX_APPID": "wx-test", "WX_SECRET": "secret"}):
            self.assertTrue(auth.auth_status()["wechat_login_configured"])
        with patch.dict(os.environ, {"WX_APPID": "", "WX_SECRET": ""}):
            self.assertFalse(auth.auth_status()["wechat_login_configured"])


def _budget(report, category_id):
    for item in report.categories:
        if item.category.id == category_id:
            return item.budget
    return None


if __name__ == "__main__":
    unittest.main()
