import csv
import io
import os
import sqlite3
import tempfile
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Literal, Optional

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel, Field

from bill_import import SOURCE_LABELS, parse_bill, suggest_category
from auth import (
    auth_status,
    bearer_token,
    create_account,
    current_profile,
    delete_account,
    list_accounts,
    login_account,
    logout_account,
    register_account,
    require_user,
    update_profile,
)
from chat_service import (
    ChatRequest,
    ChatResponse,
    RecordDraft,
    chat_with_deepseek,
    default_selection,
    provider_catalog,
)
from database import get_connection, init_db
from money import cents_to_yuan, yuan_to_cents

load_dotenv(Path(__file__).parent / ".env")

app = FastAPI(title="Account API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class CategoryOut(BaseModel):
    id: int
    name: str
    icon: str
    color: str
    type: Literal["income", "expense"]


class CategoryIn(BaseModel):
    name: str = Field(min_length=1, max_length=20)
    icon: str = Field(min_length=1, max_length=16)
    color: str = Field(pattern=r"^#[0-9A-Fa-f]{6}$")
    type: Literal["income", "expense"]


class CategoryUpdateIn(BaseModel):
    name: str = Field(min_length=1, max_length=20)
    icon: str = Field(min_length=1, max_length=16)
    color: str = Field(pattern=r"^#[0-9A-Fa-f]{6}$")


class TagOut(BaseModel):
    id: int
    category_id: int
    name: str
    sort_order: int


class TagIn(BaseModel):
    category_id: int
    name: str = Field(min_length=1, max_length=20)


class TagUpdateIn(BaseModel):
    name: str = Field(min_length=1, max_length=20)


class TransactionOut(BaseModel):
    id: int
    title: str
    category: CategoryOut
    amount: float
    type: Literal["income", "expense"]
    date: str
    tags: list[TagOut] = Field(default_factory=list)


class SummaryOut(BaseModel):
    year: int
    month: int
    income: float
    expense: float
    total: float


class CategoryReportItem(BaseModel):
    category: CategoryOut
    income: float
    expense: float
    transaction_count: int
    budget: Optional[float] = None


class CategoryReportOut(BaseModel):
    year: int
    month: int
    income: float
    expense: float
    categories: list[CategoryReportItem]
    period: Literal["week", "month", "year"] = "month"
    start: str = ""
    end: str = ""


class ImportPreviewItem(BaseModel):
    external_id: str
    title: str
    amount: float
    type: Literal["income", "expense"]
    date: str
    category_id: Optional[int] = None
    category_name: str = ""
    matched: bool = False
    counterparty: str = ""
    duplicate: bool = False
    skipped: bool = False
    skip_reason: str = ""


class ImportPreviewOut(BaseModel):
    source: Literal["alipay", "wechat", "bank"]
    source_label: str
    total: int
    ready_count: int
    duplicate_count: int
    skipped_count: int
    items: list[ImportPreviewItem]


class ImportItemIn(BaseModel):
    external_id: str = Field(min_length=1, max_length=80)
    title: str = Field(min_length=1, max_length=200)
    amount: float = Field(gt=0)
    type: Literal["income", "expense"]
    date: str
    category_id: int
    source: Literal["alipay", "wechat", "bank"]


class ImportCommitIn(BaseModel):
    items: list[ImportItemIn] = Field(min_length=1, max_length=3000)


class ImportResultOut(BaseModel):
    imported: int
    duplicates: int


class CreateTransactionIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    category_id: int
    amount: float = Field(gt=0)
    type: Literal["income", "expense"]
    date: Optional[str] = None
    tag_ids: list[int] = Field(default_factory=list, max_length=8)


class TrendPoint(BaseModel):
    year: int
    month: int
    income: float
    expense: float
    label: str = ""
    day: int = 1


class TrendOut(BaseModel):
    points: list[TrendPoint]
    income_delta: float
    expense_delta: float


class BudgetIn(BaseModel):
    category_id: int
    year: int = Field(ge=2000, le=2100)
    month: int = Field(default=1, ge=1, le=12)
    amount: float = Field(ge=0, le=100000000)
    scope: Literal["week", "month", "year"] = "month"
    anchor: Optional[str] = None


class ChatHistoryItem(BaseModel):
    id: int
    role: Literal["user", "assistant"]
    content: str
    proposal: Optional[RecordDraft] = None
    applied: bool = False


UpdateTransactionIn = CreateTransactionIn

_TRANSACTION_SELECT = """
    SELECT
        t.id,
        t.title,
        t.category_id,
        c.name AS category_name,
        c.icon AS category_icon,
        c.color AS category_color,
        c.type AS category_type,
        t.amount,
        t.amount_cents,
        t.type,
        t.date
    FROM transactions t
    JOIN categories c ON c.id = t.category_id
"""


def _stored_amount(yuan: float) -> tuple[float, int]:
    cents = yuan_to_cents(yuan)
    if cents <= 0:
        raise HTTPException(status_code=400, detail="金额需要大于 0")
    return cents / 100, cents


def _yuan_from_row(row) -> float:
    cents = row["amount_cents"]
    if cents is None:
        cents = yuan_to_cents(row["amount"])
    return cents_to_yuan(int(cents))


def _row_to_transaction(row: dict, tags: Optional[list[TagOut]] = None) -> TransactionOut:
    return TransactionOut(
        id=row["id"],
        title=row["title"],
        category=_category_out(row),
        amount=_yuan_from_row(row),
        type=row["type"],
        date=row["date"],
        tags=tags or [],
    )


def _tags_by_transaction(conn, ids: list[int]) -> dict[int, list[TagOut]]:
    if not ids:
        return {}
    placeholders = ",".join("?" * len(ids))
    rows = conn.execute(
        f"""
        SELECT tt.transaction_id, g.id, g.category_id, g.name, g.sort_order
        FROM transaction_tags tt
        JOIN tags g ON g.id = tt.tag_id
        WHERE tt.transaction_id IN ({placeholders})
        ORDER BY g.sort_order, g.id
        """,
        ids,
    ).fetchall()
    grouped: dict[int, list[TagOut]] = {}
    for row in rows:
        grouped.setdefault(int(row["transaction_id"]), []).append(
            TagOut(
                id=row["id"],
                category_id=row["category_id"],
                name=row["name"],
                sort_order=row["sort_order"],
            )
        )
    return grouped


def _set_transaction_tags(conn, tx_id: int, category_id: int, tag_ids: list[int]) -> None:
    unique: list[int] = []
    for tag_id in tag_ids:
        if tag_id not in unique:
            unique.append(tag_id)
    if unique:
        placeholders = ",".join("?" * len(unique))
        rows = conn.execute(
            f"SELECT id FROM tags WHERE category_id = ? AND id IN ({placeholders})",
            [category_id, *unique],
        ).fetchall()
        if len(rows) != len(unique):
            raise HTTPException(status_code=400, detail="标签与分类不匹配")
    conn.execute("DELETE FROM transaction_tags WHERE transaction_id = ?", (tx_id,))
    for tag_id in unique:
        conn.execute(
            "INSERT INTO transaction_tags (transaction_id, tag_id) VALUES (?, ?)",
            (tx_id, tag_id),
        )


def _like_pattern(keyword: str) -> str:
    escaped = keyword.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{escaped}%"


def _shift_month(year: int, month: int, delta: int) -> tuple[int, int]:
    index = year * 12 + (month - 1) + delta
    return index // 12, index % 12 + 1


def _parse_anchor(raw: Optional[str]) -> date:
    if not raw:
        raise HTTPException(status_code=400, detail="请选择日期")
    try:
        return date.fromisoformat(raw)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="日期格式不正确") from exc


def _month_end(year: int, month: int) -> date:
    if month == 12:
        return date(year, 12, 31)
    return date(year, month + 1, 1) - timedelta(days=1)


def _period_bounds(
    period: str,
    year: Optional[int],
    month: Optional[int],
    anchor: Optional[str],
) -> tuple[date, date]:
    if period == "week":
        day = _parse_anchor(anchor)
        monday = day - timedelta(days=day.weekday())
        return monday, monday + timedelta(days=6)
    if period == "year":
        if year is None:
            raise HTTPException(status_code=400, detail="请选择年份")
        return date(year, 1, 1), date(year, 12, 31)
    if year is None or month is None:
        raise HTTPException(status_code=400, detail="请选择月份")
    return date(year, month, 1), _month_end(year, month)


def _range_totals(conn, start: date, end: date, user_id: int) -> tuple[float, float]:
    rows = conn.execute(
        """
        SELECT type, COALESCE(SUM(amount_cents), 0) AS total
        FROM transactions
        WHERE date >= ? AND date <= ? AND user_id = ?
        GROUP BY type
        """,
        (start.isoformat(), end.isoformat(), user_id),
    ).fetchall()
    income = 0
    expense = 0
    for row in rows:
        if row["type"] == "income":
            income = int(row["total"])
        else:
            expense = int(row["total"])
    return cents_to_yuan(income), cents_to_yuan(expense)


def _parse_transaction_date(raw_date: Optional[str]) -> str:
    tx_date = raw_date or date.today().isoformat()
    try:
        datetime.fromisoformat(tx_date)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid date format") from exc
    return tx_date


def _fetch_transaction(conn, tx_id: int, user_id: int) -> TransactionOut:
    row = conn.execute(
        f"{_TRANSACTION_SELECT} WHERE t.id = ? AND t.user_id = ?",
        (tx_id, user_id),
    ).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Transaction not found")
    tags = _tags_by_transaction(conn, [tx_id]).get(tx_id, [])
    return _row_to_transaction(dict(row), tags)


def _category_out(row: dict) -> CategoryOut:
    return CategoryOut(
        id=row["category_id"],
        name=row["category_name"],
        icon=row["category_icon"],
        color=row["category_color"],
        type=row["category_type"],
    )


def _clean_category_text(value: str, *, empty_message: str) -> str:
    cleaned = value.strip()
    if not cleaned:
        raise HTTPException(status_code=400, detail=empty_message)
    return cleaned


def _category_by_id(conn, category_id: int, user_id: int):
    category = conn.execute(
        """
        SELECT id, name, icon, color, type
        FROM categories
        WHERE id = ? AND user_id = ?
        """,
        (category_id, user_id),
    ).fetchone()
    if category is None:
        raise HTTPException(status_code=404, detail="分类不存在")
    return category


def _ensure_category_matches(conn, category_id: int, tx_type: str, user_id: int) -> None:
    category = _category_by_id(conn, category_id, user_id)
    if category["type"] != tx_type:
        raise HTTPException(status_code=400, detail="分类与收支类型不匹配")


@app.on_event("startup")
def on_startup() -> None:
    init_db()


@app.get("/")
def root() -> dict:
    return {
        "name": "Account API",
        "status": "ok",
        "docs": "/docs",
        "health": "/api/health",
    }


@app.get("/api/health")
def health() -> dict:
    return {"status": "ok"}


class AuthIn(BaseModel):
    username: str
    password: str
    display_name: Optional[str] = None


class ProfileIn(BaseModel):
    display_name: Optional[str] = None
    current_password: Optional[str] = None
    new_password: Optional[str] = None


@app.get("/api/auth/status")
def get_auth_status() -> dict:
    return auth_status()


@app.post("/api/auth/register")
def register(payload: AuthIn) -> dict:
    return register_account(payload.username, payload.password, payload.display_name)


@app.post("/api/auth/login")
def login(payload: AuthIn) -> dict:
    return login_account(payload.username, payload.password)


@app.post("/api/auth/logout", status_code=204)
def logout(authorization: Optional[str] = Header(default=None)) -> None:
    logout_account(bearer_token(authorization))


@app.get("/api/auth/me")
def me(user_id: int = Depends(require_user)) -> dict:
    return current_profile(user_id)


@app.put("/api/auth/me")
def edit_me(payload: ProfileIn, user_id: int = Depends(require_user)) -> dict:
    return update_profile(
        user_id,
        payload.display_name,
        payload.current_password,
        payload.new_password,
    )


@app.get("/api/users")
def get_users(user_id: int = Depends(require_user)) -> list[dict]:
    del user_id
    return list_accounts()


@app.post("/api/users", status_code=201)
def post_user(payload: AuthIn, user_id: int = Depends(require_user)) -> dict:
    del user_id
    return create_account(payload.username, payload.password, payload.display_name)


@app.delete("/api/users/{target_id}", status_code=204)
def remove_user(target_id: int, user_id: int = Depends(require_user)) -> None:
    delete_account(user_id, target_id)


@app.get("/api/categories", response_model=list[CategoryOut])
def list_categories(
    category_type: Optional[Literal["income", "expense"]] = Query(None, alias="type"),
    user_id: int = Depends(require_user),
) -> list[CategoryOut]:
    sql = "SELECT id, name, icon, color, type FROM categories WHERE user_id = ?"
    params: list = [user_id]
    if category_type is not None:
        sql += " AND type = ?"
        params.append(category_type)
    sql += " ORDER BY id"
    with get_connection() as conn:
        rows = conn.execute(sql, params).fetchall()
    return [CategoryOut(**dict(row)) for row in rows]


@app.post("/api/categories", response_model=CategoryOut, status_code=201)
def create_category(payload: CategoryIn, user_id: int = Depends(require_user)) -> CategoryOut:
    name = _clean_category_text(payload.name, empty_message="请填写分类名称")
    icon = _clean_category_text(payload.icon, empty_message="请选择图标")
    with get_connection() as conn:
        try:
            cursor = conn.execute(
                """
                INSERT INTO categories (user_id, name, icon, color, type)
                VALUES (?, ?, ?, ?, ?)
                """,
                (user_id, name, icon, payload.color, payload.type),
            )
            conn.commit()
        except sqlite3.IntegrityError as exc:
            raise HTTPException(status_code=400, detail="该类型下已有同名分类") from exc
        category_id = cursor.lastrowid
        if category_id is None:
            raise HTTPException(status_code=500, detail="创建分类失败")
        row = _category_by_id(conn, category_id, user_id)
    return CategoryOut(**dict(row))


@app.put("/api/categories/{category_id}", response_model=CategoryOut)
def update_category(
    category_id: int,
    payload: CategoryUpdateIn,
    user_id: int = Depends(require_user),
) -> CategoryOut:
    name = _clean_category_text(payload.name, empty_message="请填写分类名称")
    icon = _clean_category_text(payload.icon, empty_message="请选择图标")
    with get_connection() as conn:
        _category_by_id(conn, category_id, user_id)
        try:
            conn.execute(
                """
                UPDATE categories
                SET name = ?, icon = ?, color = ?
                WHERE id = ? AND user_id = ?
                """,
                (name, icon, payload.color, category_id, user_id),
            )
            conn.commit()
        except sqlite3.IntegrityError as exc:
            raise HTTPException(status_code=400, detail="该类型下已有同名分类") from exc
        row = _category_by_id(conn, category_id, user_id)
    return CategoryOut(**dict(row))


@app.delete("/api/categories/{category_id}", status_code=204)
def delete_category(category_id: int, user_id: int = Depends(require_user)) -> None:
    with get_connection() as conn:
        _category_by_id(conn, category_id, user_id)
        used = conn.execute(
            "SELECT COUNT(*) FROM transactions WHERE category_id = ?",
            (category_id,),
        ).fetchone()[0]
        if used:
            raise HTTPException(status_code=400, detail="该分类下还有账单，无法删除")
        conn.execute("DELETE FROM categories WHERE id = ?", (category_id,))
        conn.commit()


def _tag_by_id(conn, tag_id: int, user_id: int):
    tag = conn.execute(
        """
        SELECT t.id, t.category_id, t.name, t.sort_order
        FROM tags t
        JOIN categories c ON c.id = t.category_id
        WHERE t.id = ? AND c.user_id = ?
        """,
        (tag_id, user_id),
    ).fetchone()
    if tag is None:
        raise HTTPException(status_code=404, detail="标签不存在")
    return tag


@app.get("/api/tags", response_model=list[TagOut])
def list_tags(
    category_id: Optional[int] = Query(None, ge=1),
    user_id: int = Depends(require_user),
) -> list[TagOut]:
    sql = """
        SELECT t.id, t.category_id, t.name, t.sort_order
        FROM tags t
        JOIN categories c ON c.id = t.category_id
        WHERE c.user_id = ?
    """
    params: list[int] = [user_id]
    if category_id is not None:
        sql += " AND t.category_id = ?"
        params.append(category_id)
    sql += " ORDER BY t.sort_order, t.id"
    with get_connection() as conn:
        if category_id is not None:
            _category_by_id(conn, category_id, user_id)
        rows = conn.execute(sql, params).fetchall()
    return [TagOut(**dict(row)) for row in rows]


@app.post("/api/tags", response_model=TagOut, status_code=201)
def create_tag(payload: TagIn, user_id: int = Depends(require_user)) -> TagOut:
    name = _clean_category_text(payload.name, empty_message="请填写标签名称")
    with get_connection() as conn:
        _category_by_id(conn, payload.category_id, user_id)
        sort_order = conn.execute(
            "SELECT COALESCE(MAX(sort_order), 0) + 1 FROM tags WHERE category_id = ?",
            (payload.category_id,),
        ).fetchone()[0]
        try:
            cursor = conn.execute(
                """
                INSERT INTO tags (category_id, name, sort_order)
                VALUES (?, ?, ?)
                """,
                (payload.category_id, name, sort_order),
            )
            conn.commit()
        except sqlite3.IntegrityError as exc:
            raise HTTPException(status_code=400, detail="该分类下已有同名标签") from exc
        tag_id = cursor.lastrowid
        if tag_id is None:
            raise HTTPException(status_code=500, detail="创建标签失败")
        row = _tag_by_id(conn, tag_id, user_id)
    return TagOut(**dict(row))


@app.put("/api/tags/{tag_id}", response_model=TagOut)
def update_tag(
    tag_id: int,
    payload: TagUpdateIn,
    user_id: int = Depends(require_user),
) -> TagOut:
    name = _clean_category_text(payload.name, empty_message="请填写标签名称")
    with get_connection() as conn:
        _tag_by_id(conn, tag_id, user_id)
        try:
            conn.execute(
                "UPDATE tags SET name = ? WHERE id = ?",
                (name, tag_id),
            )
            conn.commit()
        except sqlite3.IntegrityError as exc:
            raise HTTPException(status_code=400, detail="该分类下已有同名标签") from exc
        row = _tag_by_id(conn, tag_id, user_id)
    return TagOut(**dict(row))


@app.delete("/api/tags/{tag_id}", status_code=204)
def delete_tag(tag_id: int, user_id: int = Depends(require_user)) -> None:
    with get_connection() as conn:
        _tag_by_id(conn, tag_id, user_id)
        conn.execute("DELETE FROM tags WHERE id = ?", (tag_id,))
        conn.commit()


def _parse_range_bound(raw: str) -> date:
    try:
        return date.fromisoformat(raw[:10])
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="日期格式不正确") from exc


@app.get("/api/transactions", response_model=list[TransactionOut])
def list_transactions(
    year: Optional[int] = Query(None, ge=2000, le=2100),
    month: Optional[int] = Query(None, ge=1, le=12),
    start: Optional[str] = Query(None),
    end: Optional[str] = Query(None),
    q: Optional[str] = Query(None, max_length=50),
    category_id: Optional[int] = None,
    tx_type: Optional[Literal["income", "expense"]] = Query(None, alias="type"),
    tag_id: Optional[int] = None,
    user_id: int = Depends(require_user),
) -> list[TransactionOut]:
    range_start = _parse_range_bound(start) if start else None
    range_end = _parse_range_bound(end) if end else None
    if (range_start is None) != (range_end is None):
        raise HTTPException(status_code=400, detail="请选择完整的日期范围")
    if range_start is not None and range_end is not None and range_end < range_start:
        raise HTTPException(status_code=400, detail="日期范围不正确")
    if range_start is None and (year is None or month is None):
        raise HTTPException(status_code=400, detail="请选择月份")
    if range_start is not None and range_end is not None:
        date_sql = "substr(t.date, 1, 10) >= ? AND substr(t.date, 1, 10) <= ?"
        date_params = [range_start.isoformat(), range_end.isoformat()]
    else:
        date_sql = "t.date LIKE ?"
        date_params = [f"{year:04d}-{month:02d}%"]
    keyword = (q or "").strip()
    pattern = _like_pattern(keyword) if keyword else None
    with get_connection() as conn:
        rows = conn.execute(
            f"""
            {_TRANSACTION_SELECT}
            WHERE t.user_id = ?
              AND {date_sql}
              AND (? IS NULL OR t.category_id = ?)
              AND (? IS NULL OR t.type = ?)
              AND (
                    ? IS NULL
                    OR t.title LIKE ? ESCAPE '\\'
                    OR c.name LIKE ? ESCAPE '\\'
                    OR EXISTS (
                        SELECT 1
                        FROM transaction_tags tt
                        JOIN tags g ON g.id = tt.tag_id
                        WHERE tt.transaction_id = t.id
                          AND g.name LIKE ? ESCAPE '\\'
                    )
                  )
              AND (
                    ? IS NULL
                    OR EXISTS (
                        SELECT 1
                        FROM transaction_tags tt
                        WHERE tt.transaction_id = t.id AND tt.tag_id = ?
                    )
                  )
            ORDER BY t.date DESC, t.id DESC
            """,
            (
                user_id,
                *date_params,
                category_id,
                category_id,
                tx_type,
                tx_type,
                pattern,
                pattern,
                pattern,
                pattern,
                tag_id,
                tag_id,
            ),
        ).fetchall()
        tags = _tags_by_transaction(conn, [int(row["id"]) for row in rows])
    return [
        _row_to_transaction(dict(row), tags.get(int(row["id"]), []))
        for row in rows
    ]


@app.get("/api/transactions/summary", response_model=SummaryOut)
def transaction_summary(
    year: int = Query(..., ge=2000, le=2100),
    month: int = Query(..., ge=1, le=12),
    user_id: int = Depends(require_user),
) -> SummaryOut:
    month_prefix = f"{year:04d}-{month:02d}"
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT type, COALESCE(SUM(amount_cents), 0) AS total
            FROM transactions
            WHERE date LIKE ? AND user_id = ?
            GROUP BY type
            """,
            (f"{month_prefix}%", user_id),
        ).fetchall()

    income = 0
    expense = 0
    for row in rows:
        if row["type"] == "income":
            income = int(row["total"])
        else:
            expense = int(row["total"])

    return SummaryOut(
        year=year,
        month=month,
        income=cents_to_yuan(income),
        expense=cents_to_yuan(expense),
        total=cents_to_yuan(income - expense),
    )


@app.get("/api/reports/categories", response_model=CategoryReportOut)
def category_report(
    period: Literal["week", "month", "year"] = Query("month"),
    year: Optional[int] = Query(None, ge=2000, le=2100),
    month: Optional[int] = Query(None, ge=1, le=12),
    anchor: Optional[str] = Query(None),
    user_id: int = Depends(require_user),
) -> CategoryReportOut:
    start, end = _period_bounds(period, year, month, anchor)
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT
                c.id AS category_id,
                c.name AS category_name,
                c.icon AS category_icon,
                c.color AS category_color,
                c.type AS category_type,
                t.type,
                COALESCE(SUM(t.amount_cents), 0) AS total,
                COUNT(t.id) AS transaction_count
            FROM categories c
            LEFT JOIN transactions t
                ON t.category_id = c.id
                AND t.date >= ? AND t.date <= ?
                AND t.user_id = ?
            WHERE c.user_id = ?
            GROUP BY c.id, c.name, c.icon, c.color, c.type, t.type
            ORDER BY c.id
            """,
            (start.isoformat(), end.isoformat(), user_id, user_id),
        ).fetchall()

        income, expense = _range_totals(conn, start, end, user_id)
        if period == "week":
            budget_scope, budget_key = "week", start.isoformat()
        elif period == "year":
            budget_scope, budget_key = "year", f"{start.year:04d}"
        else:
            budget_scope, budget_key = "month", f"{start.year:04d}-{start.month:02d}"
        budget_rows = conn.execute(
            """
            SELECT b.category_id, b.amount_cents
            FROM budgets b
            JOIN categories c ON c.id = b.category_id
            WHERE b.scope = ? AND b.period_key = ? AND c.user_id = ?
            """,
            (budget_scope, budget_key, user_id),
        ).fetchall()

    budgets = {
        int(row["category_id"]): cents_to_yuan(int(row["amount_cents"]))
        for row in budget_rows
    }

    category_map: dict[int, dict] = {}
    for row in rows:
        category_id = row["category_id"]
        if category_id not in category_map:
            category_map[category_id] = {
                "category": _category_out(row),
                "income": 0.0,
                "expense": 0.0,
                "transaction_count": 0,
            }

        entry = category_map[category_id]
        amount = cents_to_yuan(int(row["total"]))
        count = int(row["transaction_count"])
        if row["type"] == "income":
            entry["income"] += amount
            entry["transaction_count"] += count
        elif row["type"] == "expense":
            entry["expense"] += amount
            entry["transaction_count"] += count

    for category_id, entry in category_map.items():
        entry["budget"] = budgets.get(category_id)

    categories = [
        CategoryReportItem(
            category=item["category"],
            income=item["income"],
            expense=item["expense"],
            transaction_count=item["transaction_count"],
            budget=item.get("budget"),
        )
        for item in category_map.values()
        if item["transaction_count"] > 0 or item.get("budget")
    ]
    categories.sort(key=lambda item: item.expense + item.income, reverse=True)

    return CategoryReportOut(
        year=start.year,
        month=start.month,
        income=income,
        expense=expense,
        categories=categories,
        period=period,
        start=start.isoformat(),
        end=end.isoformat(),
    )


@app.post("/api/transactions", response_model=TransactionOut, status_code=201)
def create_transaction(
    payload: CreateTransactionIn,
    user_id: int = Depends(require_user),
) -> TransactionOut:
    tx_date = _parse_transaction_date(payload.date)

    with get_connection() as conn:
        _ensure_category_matches(conn, payload.category_id, payload.type, user_id)

        stored, cents = _stored_amount(payload.amount)
        cursor = conn.execute(
            """
            INSERT INTO transactions
                (user_id, title, category_id, amount, amount_cents, type, date)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                user_id,
                payload.title.strip(),
                payload.category_id,
                stored,
                cents,
                payload.type,
                tx_date,
            ),
        )
        tx_id = cursor.lastrowid
        _set_transaction_tags(conn, tx_id, payload.category_id, payload.tag_ids)
        conn.commit()
        return _fetch_transaction(conn, tx_id, user_id)


@app.put("/api/transactions/{transaction_id}", response_model=TransactionOut)
def update_transaction(
    transaction_id: int,
    payload: UpdateTransactionIn,
    user_id: int = Depends(require_user),
) -> TransactionOut:
    tx_date = _parse_transaction_date(payload.date)

    with get_connection() as conn:
        existing = conn.execute(
            "SELECT id FROM transactions WHERE id = ? AND user_id = ?",
            (transaction_id, user_id),
        ).fetchone()
        if existing is None:
            raise HTTPException(status_code=404, detail="Transaction not found")

        _ensure_category_matches(conn, payload.category_id, payload.type, user_id)

        stored, cents = _stored_amount(payload.amount)
        conn.execute(
            """
            UPDATE transactions
            SET title = ?, category_id = ?, amount = ?, amount_cents = ?, type = ?, date = ?
            WHERE id = ? AND user_id = ?
            """,
            (
                payload.title.strip(),
                payload.category_id,
                stored,
                cents,
                payload.type,
                tx_date,
                transaction_id,
                user_id,
            ),
        )
        _set_transaction_tags(conn, transaction_id, payload.category_id, payload.tag_ids)
        conn.commit()
        return _fetch_transaction(conn, transaction_id, user_id)


@app.delete("/api/transactions/{transaction_id}", status_code=204)
def delete_transaction(transaction_id: int, user_id: int = Depends(require_user)) -> None:
    with get_connection() as conn:
        cursor = conn.execute(
            "DELETE FROM transactions WHERE id = ? AND user_id = ?",
            (transaction_id, user_id),
        )
        conn.commit()
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Transaction not found")


@app.post("/api/imports/preview", response_model=ImportPreviewOut)
async def preview_import(
    file: UploadFile = File(...),
    source: Optional[Literal["alipay", "wechat", "bank"]] = Form(None),
    user_id: int = Depends(require_user),
) -> ImportPreviewOut:
    filename = file.filename or "bill.csv"
    content = await file.read()
    detected, bills = parse_bill(content, filename, source)
    if len(bills) > 3000:
        raise HTTPException(status_code=400, detail="一次最多导入 3000 条记录")

    with get_connection() as conn:
        categories = [
            (row["id"], row["name"], row["type"])
            for row in conn.execute(
                "SELECT id, name, type FROM categories WHERE user_id = ? ORDER BY id",
                (user_id,),
            )
        ]
        existing = {
            (row["source"], row["external_id"])
            for row in conn.execute(
                """
                SELECT source, external_id
                FROM transactions
                WHERE user_id = ? AND source IS NOT NULL AND external_id IS NOT NULL
                """,
                (user_id,),
            )
        }

    items: list[ImportPreviewItem] = []
    seen: set[tuple[str, str]] = set()
    ready_count = 0
    duplicate_count = 0
    skipped_count = 0
    for bill in bills:
        category_id, category_name, matched = suggest_category(
            bill.hint, bill.tx_type, categories
        )
        duplicate = (bill.source, bill.external_id) in existing or (
            bill.source,
            bill.external_id,
        ) in seen
        seen.add((bill.source, bill.external_id))
        skipped = bill.skipped or category_id is None
        reason = bill.skip_reason
        if category_id is None and not bill.skipped:
            reason = "没有可归入的分类"
        if skipped:
            skipped_count += 1
        elif duplicate:
            duplicate_count += 1
        else:
            ready_count += 1
        items.append(
            ImportPreviewItem(
                external_id=bill.external_id,
                title=bill.title,
                amount=round(bill.amount, 2),
                type=bill.tx_type,
                date=bill.date,
                category_id=category_id,
                category_name=category_name,
                matched=matched,
                counterparty=bill.counterparty,
                duplicate=duplicate and not skipped,
                skipped=skipped,
                skip_reason=reason,
            )
        )

    return ImportPreviewOut(
        source=detected,
        source_label=SOURCE_LABELS[detected],
        total=len(items),
        ready_count=ready_count,
        duplicate_count=duplicate_count,
        skipped_count=skipped_count,
        items=items,
    )


@app.post("/api/imports/commit", response_model=ImportResultOut)
def commit_import(
    payload: ImportCommitIn,
    user_id: int = Depends(require_user),
) -> ImportResultOut:
    imported = 0
    duplicates = 0
    with get_connection() as conn:
        for item in payload.items:
            _ensure_category_matches(conn, item.category_id, item.type, user_id)
            tx_date = _parse_transaction_date(item.date)
            stored, cents = _stored_amount(item.amount)
            try:
                conn.execute(
                    """
                    INSERT INTO transactions
                        (user_id, title, category_id, amount, amount_cents, type, date, source, external_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        user_id,
                        item.title.strip(),
                        item.category_id,
                        stored,
                        cents,
                        item.type,
                        tx_date,
                        item.source,
                        item.external_id,
                    ),
                )
                imported += 1
            except sqlite3.IntegrityError:
                duplicates += 1
        conn.commit()
    return ImportResultOut(imported=imported, duplicates=duplicates)


@app.get("/api/reports/trend", response_model=TrendOut)
def report_trend(
    period: Literal["week", "month", "year"] = Query("month"),
    year: Optional[int] = Query(None, ge=2000, le=2100),
    month: Optional[int] = Query(None, ge=1, le=12),
    anchor: Optional[str] = Query(None),
    months: int = Query(6, ge=2, le=12),
    user_id: int = Depends(require_user),
) -> TrendOut:
    start, end = _period_bounds(period, year, month, anchor)
    points: list[TrendPoint] = []
    with get_connection() as conn:
        if period == "week":
            for offset in range(7, -1, -1):
                week_start = start - timedelta(days=7 * offset)
                week_end = week_start + timedelta(days=6)
                income, expense = _range_totals(conn, week_start, week_end, user_id)
                points.append(
                    TrendPoint(
                        year=week_start.year,
                        month=week_start.month,
                        day=week_start.day,
                        label=f"{week_start.month}/{week_start.day}",
                        income=income,
                        expense=expense,
                    )
                )
            income_delta = points[-1].income - points[-2].income
            expense_delta = points[-1].expense - points[-2].expense
        elif period == "year":
            for point_month in range(1, 13):
                point_start = date(start.year, point_month, 1)
                point_end = _month_end(start.year, point_month)
                income, expense = _range_totals(conn, point_start, point_end, user_id)
                points.append(
                    TrendPoint(
                        year=start.year,
                        month=point_month,
                        label=str(point_month),
                        income=income,
                        expense=expense,
                    )
                )
            previous_income, previous_expense = _range_totals(
                conn,
                date(start.year - 1, 1, 1),
                date(start.year - 1, 12, 31),
                user_id,
            )
            income_delta = sum(point.income for point in points) - previous_income
            expense_delta = sum(point.expense for point in points) - previous_expense
        else:
            for offset in range(months - 1, -1, -1):
                point_year, point_month = _shift_month(start.year, start.month, -offset)
                point_start = date(point_year, point_month, 1)
                point_end = _month_end(point_year, point_month)
                income, expense = _range_totals(conn, point_start, point_end, user_id)
                points.append(
                    TrendPoint(
                        year=point_year,
                        month=point_month,
                        label=f"{point_month}月",
                        income=income,
                        expense=expense,
                    )
                )
            income_delta = points[-1].income - points[-2].income
            expense_delta = points[-1].expense - points[-2].expense
    return TrendOut(
        points=points,
        income_delta=round(income_delta, 2),
        expense_delta=round(expense_delta, 2),
    )


def _budget_period_key(payload: BudgetIn) -> str:
    if payload.scope == "year":
        return f"{payload.year:04d}"
    if payload.scope == "week":
        day = _parse_anchor(payload.anchor)
        monday = day - timedelta(days=day.weekday())
        return monday.isoformat()
    return f"{payload.year:04d}-{payload.month:02d}"


@app.put("/api/budgets", status_code=204)
def upsert_budget(payload: BudgetIn, user_id: int = Depends(require_user)) -> None:
    period_key = _budget_period_key(payload)
    with get_connection() as conn:
        category = _category_by_id(conn, payload.category_id, user_id)
        if category["type"] != "expense":
            raise HTTPException(status_code=400, detail="只有支出分类可以设置预算")
        if payload.amount <= 0:
            conn.execute(
                """
                DELETE FROM budgets
                WHERE category_id = ? AND scope = ? AND period_key = ?
                """,
                (payload.category_id, payload.scope, period_key),
            )
        else:
            cents = yuan_to_cents(payload.amount)
            if cents <= 0:
                raise HTTPException(status_code=400, detail="金额需要大于 0")
            conn.execute(
                """
                INSERT INTO budgets (category_id, scope, period_key, amount_cents)
                VALUES (?, ?, ?, ?)
                ON CONFLICT (category_id, scope, period_key)
                DO UPDATE SET amount_cents = excluded.amount_cents
                """,
                (payload.category_id, payload.scope, period_key, cents),
            )
        conn.commit()


@app.get("/api/exports/transactions.csv")
def export_transactions_csv(user_id: int = Depends(require_user)) -> Response:
    with get_connection() as conn:
        rows = conn.execute(
            f"{_TRANSACTION_SELECT} WHERE t.user_id = ? ORDER BY t.date DESC, t.id DESC",
            (user_id,),
        ).fetchall()
        tags = _tags_by_transaction(conn, [int(row["id"]) for row in rows])
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(["日期", "类型", "分类", "标题", "金额", "标签"])
    for row in rows:
        tag_names = " ".join(tag.name for tag in tags.get(int(row["id"]), []))
        writer.writerow(
            [
                row["date"],
                "收入" if row["type"] == "income" else "支出",
                row["category_name"],
                row["title"],
                f"{_yuan_from_row(row):.2f}",
                tag_names,
            ]
        )
    body = ("\ufeff" + buffer.getvalue()).encode("utf-8")
    return Response(
        content=body,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": 'attachment; filename="transactions.csv"'},
    )


_LEDGER_SCHEMA = """
CREATE TABLE categories (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    icon TEXT NOT NULL,
    color TEXT NOT NULL,
    type TEXT NOT NULL
);
CREATE TABLE tags (
    id INTEGER PRIMARY KEY,
    category_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE transactions (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    category_id INTEGER NOT NULL,
    amount REAL NOT NULL,
    amount_cents INTEGER NOT NULL,
    type TEXT NOT NULL,
    date TEXT NOT NULL,
    source TEXT,
    external_id TEXT
);
CREATE TABLE transaction_tags (
    transaction_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    PRIMARY KEY (transaction_id, tag_id)
);
CREATE TABLE budgets (
    category_id INTEGER NOT NULL,
    scope TEXT NOT NULL,
    period_key TEXT NOT NULL,
    amount_cents INTEGER NOT NULL,
    PRIMARY KEY (category_id, scope, period_key)
);
CREATE TABLE chat_messages (
    id INTEGER PRIMARY KEY,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    proposal TEXT,
    applied INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
);
"""


def _insert_rows(dest: sqlite3.Connection, sql: str, rows) -> None:
    if rows:
        dest.executemany(sql, [tuple(row) for row in rows])


@app.get("/api/exports/backup.db")
def export_backup(user_id: int = Depends(require_user)) -> Response:
    fd, path = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    try:
        dest = sqlite3.connect(path)
        try:
            dest.executescript(_LEDGER_SCHEMA)
            with get_connection() as conn:
                categories = conn.execute(
                    """
                    SELECT id, name, icon, color, type
                    FROM categories WHERE user_id = ? ORDER BY id
                    """,
                    (user_id,),
                ).fetchall()
                tags = conn.execute(
                    """
                    SELECT t.id, t.category_id, t.name, t.sort_order
                    FROM tags t
                    JOIN categories c ON c.id = t.category_id
                    WHERE c.user_id = ?
                    ORDER BY t.id
                    """,
                    (user_id,),
                ).fetchall()
                transactions = conn.execute(
                    """
                    SELECT id, title, category_id, amount, amount_cents, type, date, source, external_id
                    FROM transactions WHERE user_id = ? ORDER BY id
                    """,
                    (user_id,),
                ).fetchall()
                links = conn.execute(
                    """
                    SELECT tt.transaction_id, tt.tag_id
                    FROM transaction_tags tt
                    JOIN transactions tx ON tx.id = tt.transaction_id
                    WHERE tx.user_id = ?
                    """,
                    (user_id,),
                ).fetchall()
                budgets = conn.execute(
                    """
                    SELECT b.category_id, b.scope, b.period_key, b.amount_cents
                    FROM budgets b
                    JOIN categories c ON c.id = b.category_id
                    WHERE c.user_id = ?
                    """,
                    (user_id,),
                ).fetchall()
                messages = conn.execute(
                    """
                    SELECT id, role, content, proposal, applied, created_at
                    FROM chat_messages WHERE user_id = ? ORDER BY id
                    """,
                    (user_id,),
                ).fetchall()
            _insert_rows(
                dest,
                "INSERT INTO categories (id, name, icon, color, type) VALUES (?, ?, ?, ?, ?)",
                categories,
            )
            _insert_rows(
                dest,
                "INSERT INTO tags (id, category_id, name, sort_order) VALUES (?, ?, ?, ?)",
                tags,
            )
            _insert_rows(
                dest,
                """
                INSERT INTO transactions
                    (id, title, category_id, amount, amount_cents, type, date, source, external_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                transactions,
            )
            _insert_rows(
                dest,
                "INSERT INTO transaction_tags (transaction_id, tag_id) VALUES (?, ?)",
                links,
            )
            _insert_rows(
                dest,
                """
                INSERT INTO budgets (category_id, scope, period_key, amount_cents)
                VALUES (?, ?, ?, ?)
                """,
                budgets,
            )
            _insert_rows(
                dest,
                """
                INSERT INTO chat_messages
                    (id, role, content, proposal, applied, created_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                messages,
            )
            dest.commit()
        finally:
            dest.close()
        body = Path(path).read_bytes()
    finally:
        os.unlink(path)
    return Response(
        content=body,
        media_type="application/octet-stream",
        headers={"Content-Disposition": 'attachment; filename="account-backup.db"'},
    )


def _proposal_from_json(raw: Optional[str]) -> Optional[RecordDraft]:
    if not raw:
        return None
    try:
        return RecordDraft.model_validate_json(raw)
    except ValueError:
        return None


def _save_chat_turn(
    user_id: int,
    user_text: str,
    reply: str,
    proposal: Optional[RecordDraft],
) -> int:
    now = datetime.now().isoformat(timespec="seconds")
    proposal_json = proposal.model_dump_json() if proposal is not None else None
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO chat_messages (user_id, role, content, proposal, applied, created_at)
            VALUES (?, 'user', ?, NULL, 0, ?)
            """,
            (user_id, user_text, now),
        )
        cursor = conn.execute(
            """
            INSERT INTO chat_messages (user_id, role, content, proposal, applied, created_at)
            VALUES (?, 'assistant', ?, ?, 0, ?)
            """,
            (user_id, reply, proposal_json, now),
        )
        conn.commit()
        return int(cursor.lastrowid)


@app.get("/api/chat/history", response_model=list[ChatHistoryItem])
def chat_history(user_id: int = Depends(require_user)) -> list[ChatHistoryItem]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT id, role, content, proposal, applied
            FROM chat_messages
            WHERE user_id = ?
            ORDER BY id DESC
            LIMIT 200
            """,
            (user_id,),
        ).fetchall()
    items = [
        ChatHistoryItem(
            id=int(row["id"]),
            role=row["role"],
            content=row["content"],
            proposal=_proposal_from_json(row["proposal"]),
            applied=bool(row["applied"]),
        )
        for row in reversed(rows)
    ]
    return items


@app.delete("/api/chat/history", status_code=204)
def clear_chat_history(user_id: int = Depends(require_user)) -> None:
    with get_connection() as conn:
        conn.execute("DELETE FROM chat_messages WHERE user_id = ?", (user_id,))
        conn.commit()


@app.post("/api/chat/messages/{message_id}/applied", status_code=204)
def mark_chat_applied(message_id: int, user_id: int = Depends(require_user)) -> None:
    with get_connection() as conn:
        cursor = conn.execute(
            """
            UPDATE chat_messages
            SET applied = 1
            WHERE id = ? AND role = 'assistant' AND user_id = ?
            """,
            (message_id, user_id),
        )
        conn.commit()
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="对话不存在")


@app.get("/api/chat/status")
def chat_status(user_id: int = Depends(require_user)) -> dict:
    del user_id
    provider, model = default_selection()
    providers = provider_catalog()
    return {
        "configured": any(item["configured"] for item in providers),
        "provider": provider,
        "model": model,
        "providers": providers,
    }


@app.post("/api/chat", response_model=ChatResponse)
async def chat(payload: ChatRequest, user_id: int = Depends(require_user)) -> ChatResponse:
    result = await chat_with_deepseek(payload, user_id)
    user_text = ""
    if payload.messages and payload.messages[-1].role == "user":
        user_text = payload.messages[-1].content
    message_id = (
        _save_chat_turn(user_id, user_text, result.reply, result.proposal) if user_text else None
    )
    return result.model_copy(update={"assistant_message_id": message_id})
