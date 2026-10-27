import sqlite3
from datetime import date, datetime
from pathlib import Path
from typing import Literal, Optional

from dotenv import load_dotenv
from fastapi import FastAPI, File, Form, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from bill_import import SOURCE_LABELS, parse_bill, suggest_category
from chat_service import (
    ChatRequest,
    ChatResponse,
    chat_with_deepseek,
    default_selection,
    provider_catalog,
)
from database import get_connection, init_db

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


class CategoryReportOut(BaseModel):
    year: int
    month: int
    income: float
    expense: float
    categories: list[CategoryReportItem]


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
        t.type,
        t.date
    FROM transactions t
    JOIN categories c ON c.id = t.category_id
"""


def _row_to_transaction(row: dict) -> TransactionOut:
    return TransactionOut(
        id=row["id"],
        title=row["title"],
        category=_category_out(row),
        amount=row["amount"],
        type=row["type"],
        date=row["date"],
    )


def _parse_transaction_date(raw_date: Optional[str]) -> str:
    tx_date = raw_date or date.today().isoformat()
    try:
        datetime.fromisoformat(tx_date)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid date format") from exc
    return tx_date


def _fetch_transaction(conn, tx_id: int) -> TransactionOut:
    row = conn.execute(
        f"{_TRANSACTION_SELECT} WHERE t.id = ?",
        (tx_id,),
    ).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return _row_to_transaction(dict(row))


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


def _category_by_id(conn, category_id: int):
    category = conn.execute(
        "SELECT id, name, icon, color, type FROM categories WHERE id = ?",
        (category_id,),
    ).fetchone()
    if category is None:
        raise HTTPException(status_code=404, detail="分类不存在")
    return category


def _ensure_category_matches(conn, category_id: int, tx_type: str) -> None:
    category = _category_by_id(conn, category_id)
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


@app.get("/api/categories", response_model=list[CategoryOut])
def list_categories(
    category_type: Optional[Literal["income", "expense"]] = Query(None, alias="type"),
) -> list[CategoryOut]:
    sql = "SELECT id, name, icon, color, type FROM categories"
    params: list[str] = []
    if category_type is not None:
        sql += " WHERE type = ?"
        params.append(category_type)
    sql += " ORDER BY id"
    with get_connection() as conn:
        rows = conn.execute(sql, params).fetchall()
    return [CategoryOut(**dict(row)) for row in rows]


@app.post("/api/categories", response_model=CategoryOut, status_code=201)
def create_category(payload: CategoryIn) -> CategoryOut:
    name = _clean_category_text(payload.name, empty_message="请填写分类名称")
    icon = _clean_category_text(payload.icon, empty_message="请选择图标")
    with get_connection() as conn:
        try:
            cursor = conn.execute(
                """
                INSERT INTO categories (name, icon, color, type)
                VALUES (?, ?, ?, ?)
                """,
                (name, icon, payload.color, payload.type),
            )
            conn.commit()
        except sqlite3.IntegrityError as exc:
            raise HTTPException(status_code=400, detail="该类型下已有同名分类") from exc
        category_id = cursor.lastrowid
        if category_id is None:
            raise HTTPException(status_code=500, detail="创建分类失败")
        row = _category_by_id(conn, category_id)
    return CategoryOut(**dict(row))


@app.put("/api/categories/{category_id}", response_model=CategoryOut)
def update_category(category_id: int, payload: CategoryUpdateIn) -> CategoryOut:
    name = _clean_category_text(payload.name, empty_message="请填写分类名称")
    icon = _clean_category_text(payload.icon, empty_message="请选择图标")
    with get_connection() as conn:
        _category_by_id(conn, category_id)
        try:
            conn.execute(
                """
                UPDATE categories
                SET name = ?, icon = ?, color = ?
                WHERE id = ?
                """,
                (name, icon, payload.color, category_id),
            )
            conn.commit()
        except sqlite3.IntegrityError as exc:
            raise HTTPException(status_code=400, detail="该类型下已有同名分类") from exc
        row = _category_by_id(conn, category_id)
    return CategoryOut(**dict(row))


@app.delete("/api/categories/{category_id}", status_code=204)
def delete_category(category_id: int) -> None:
    with get_connection() as conn:
        _category_by_id(conn, category_id)
        used = conn.execute(
            "SELECT COUNT(*) FROM transactions WHERE category_id = ?",
            (category_id,),
        ).fetchone()[0]
        if used:
            raise HTTPException(status_code=400, detail="该分类下还有账单，无法删除")
        conn.execute("DELETE FROM categories WHERE id = ?", (category_id,))
        conn.commit()


def _tag_by_id(conn, tag_id: int):
    tag = conn.execute(
        "SELECT id, category_id, name, sort_order FROM tags WHERE id = ?",
        (tag_id,),
    ).fetchone()
    if tag is None:
        raise HTTPException(status_code=404, detail="标签不存在")
    return tag


@app.get("/api/tags", response_model=list[TagOut])
def list_tags(
    category_id: Optional[int] = Query(None, ge=1),
) -> list[TagOut]:
    sql = "SELECT id, category_id, name, sort_order FROM tags"
    params: list[int] = []
    if category_id is not None:
        sql += " WHERE category_id = ?"
        params.append(category_id)
    sql += " ORDER BY sort_order, id"
    with get_connection() as conn:
        if category_id is not None:
            _category_by_id(conn, category_id)
        rows = conn.execute(sql, params).fetchall()
    return [TagOut(**dict(row)) for row in rows]


@app.post("/api/tags", response_model=TagOut, status_code=201)
def create_tag(payload: TagIn) -> TagOut:
    name = _clean_category_text(payload.name, empty_message="请填写标签名称")
    with get_connection() as conn:
        _category_by_id(conn, payload.category_id)
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
        row = _tag_by_id(conn, tag_id)
    return TagOut(**dict(row))


@app.put("/api/tags/{tag_id}", response_model=TagOut)
def update_tag(tag_id: int, payload: TagUpdateIn) -> TagOut:
    name = _clean_category_text(payload.name, empty_message="请填写标签名称")
    with get_connection() as conn:
        _tag_by_id(conn, tag_id)
        try:
            conn.execute(
                "UPDATE tags SET name = ? WHERE id = ?",
                (name, tag_id),
            )
            conn.commit()
        except sqlite3.IntegrityError as exc:
            raise HTTPException(status_code=400, detail="该分类下已有同名标签") from exc
        row = _tag_by_id(conn, tag_id)
    return TagOut(**dict(row))


@app.delete("/api/tags/{tag_id}", status_code=204)
def delete_tag(tag_id: int) -> None:
    with get_connection() as conn:
        _tag_by_id(conn, tag_id)
        conn.execute("DELETE FROM tags WHERE id = ?", (tag_id,))
        conn.commit()


@app.get("/api/transactions", response_model=list[TransactionOut])
def list_transactions(
    year: int = Query(..., ge=2000, le=2100),
    month: int = Query(..., ge=1, le=12),
) -> list[TransactionOut]:
    month_prefix = f"{year:04d}-{month:02d}"
    with get_connection() as conn:
        rows = conn.execute(
            f"""
            {_TRANSACTION_SELECT}
            WHERE t.date LIKE ?
            ORDER BY t.date DESC, t.id DESC
            """,
            (f"{month_prefix}%",),
        ).fetchall()
    return [_row_to_transaction(dict(row)) for row in rows]


@app.get("/api/transactions/summary", response_model=SummaryOut)
def transaction_summary(
    year: int = Query(..., ge=2000, le=2100),
    month: int = Query(..., ge=1, le=12),
) -> SummaryOut:
    month_prefix = f"{year:04d}-{month:02d}"
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT type, COALESCE(SUM(amount), 0) AS total
            FROM transactions
            WHERE date LIKE ?
            GROUP BY type
            """,
            (f"{month_prefix}%",),
        ).fetchall()

    income = 0.0
    expense = 0.0
    for row in rows:
        if row["type"] == "income":
            income = float(row["total"])
        else:
            expense = float(row["total"])

    return SummaryOut(
        year=year,
        month=month,
        income=income,
        expense=expense,
        total=income - expense,
    )


@app.get("/api/reports/categories", response_model=CategoryReportOut)
def category_report(
    year: int = Query(..., ge=2000, le=2100),
    month: int = Query(..., ge=1, le=12),
) -> CategoryReportOut:
    month_prefix = f"{year:04d}-{month:02d}"
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
                COALESCE(SUM(t.amount), 0) AS total,
                COUNT(t.id) AS transaction_count
            FROM categories c
            LEFT JOIN transactions t
                ON t.category_id = c.id AND t.date LIKE ?
            GROUP BY c.id, c.name, c.icon, c.color, c.type, t.type
            ORDER BY c.id
            """,
            (f"{month_prefix}%",),
        ).fetchall()

        summary_rows = conn.execute(
            """
            SELECT type, COALESCE(SUM(amount), 0) AS total
            FROM transactions
            WHERE date LIKE ?
            GROUP BY type
            """,
            (f"{month_prefix}%",),
        ).fetchall()

    income = 0.0
    expense = 0.0
    for row in summary_rows:
        if row["type"] == "income":
            income = float(row["total"])
        else:
            expense = float(row["total"])

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
        amount = float(row["total"])
        count = int(row["transaction_count"])
        if row["type"] == "income":
            entry["income"] += amount
            entry["transaction_count"] += count
        elif row["type"] == "expense":
            entry["expense"] += amount
            entry["transaction_count"] += count

    categories = [
        CategoryReportItem(
            category=item["category"],
            income=item["income"],
            expense=item["expense"],
            transaction_count=item["transaction_count"],
        )
        for item in category_map.values()
        if item["transaction_count"] > 0
    ]
    categories.sort(key=lambda item: item.expense + item.income, reverse=True)

    return CategoryReportOut(
        year=year,
        month=month,
        income=income,
        expense=expense,
        categories=categories,
    )


@app.post("/api/transactions", response_model=TransactionOut, status_code=201)
def create_transaction(payload: CreateTransactionIn) -> TransactionOut:
    tx_date = _parse_transaction_date(payload.date)

    with get_connection() as conn:
        _ensure_category_matches(conn, payload.category_id, payload.type)

        cursor = conn.execute(
            """
            INSERT INTO transactions (title, category_id, amount, type, date)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                payload.title.strip(),
                payload.category_id,
                payload.amount,
                payload.type,
                tx_date,
            ),
        )
        conn.commit()
        tx_id = cursor.lastrowid
        return _fetch_transaction(conn, tx_id)


@app.put("/api/transactions/{transaction_id}", response_model=TransactionOut)
def update_transaction(
    transaction_id: int,
    payload: UpdateTransactionIn,
) -> TransactionOut:
    tx_date = _parse_transaction_date(payload.date)

    with get_connection() as conn:
        existing = conn.execute(
            "SELECT id FROM transactions WHERE id = ?",
            (transaction_id,),
        ).fetchone()
        if existing is None:
            raise HTTPException(status_code=404, detail="Transaction not found")

        _ensure_category_matches(conn, payload.category_id, payload.type)

        conn.execute(
            """
            UPDATE transactions
            SET title = ?, category_id = ?, amount = ?, type = ?, date = ?
            WHERE id = ?
            """,
            (
                payload.title.strip(),
                payload.category_id,
                payload.amount,
                payload.type,
                tx_date,
                transaction_id,
            ),
        )
        conn.commit()
        return _fetch_transaction(conn, transaction_id)


@app.delete("/api/transactions/{transaction_id}", status_code=204)
def delete_transaction(transaction_id: int) -> None:
    with get_connection() as conn:
        cursor = conn.execute(
            "DELETE FROM transactions WHERE id = ?",
            (transaction_id,),
        )
        conn.commit()
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Transaction not found")


@app.post("/api/imports/preview", response_model=ImportPreviewOut)
async def preview_import(
    file: UploadFile = File(...),
    source: Optional[Literal["alipay", "wechat", "bank"]] = Form(None),
) -> ImportPreviewOut:
    filename = file.filename or "bill.csv"
    content = await file.read()
    detected, bills = parse_bill(content, filename, source)
    if len(bills) > 3000:
        raise HTTPException(status_code=400, detail="一次最多导入 3000 条记录")

    with get_connection() as conn:
        categories = [
            (row["id"], row["name"], row["type"])
            for row in conn.execute("SELECT id, name, type FROM categories ORDER BY id")
        ]
        existing = {
            (row["source"], row["external_id"])
            for row in conn.execute(
                """
                SELECT source, external_id
                FROM transactions
                WHERE source IS NOT NULL AND external_id IS NOT NULL
                """
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
def commit_import(payload: ImportCommitIn) -> ImportResultOut:
    imported = 0
    duplicates = 0
    with get_connection() as conn:
        for item in payload.items:
            _ensure_category_matches(conn, item.category_id, item.type)
            tx_date = _parse_transaction_date(item.date)
            try:
                conn.execute(
                    """
                    INSERT INTO transactions
                        (title, category_id, amount, type, date, source, external_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        item.title.strip(),
                        item.category_id,
                        item.amount,
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


@app.get("/api/chat/status")
def chat_status() -> dict:
    provider, model = default_selection()
    providers = provider_catalog()
    return {
        "configured": any(item["configured"] for item in providers),
        "provider": provider,
        "model": model,
        "providers": providers,
    }


@app.post("/api/chat", response_model=ChatResponse)
async def chat(payload: ChatRequest) -> ChatResponse:
    return await chat_with_deepseek(payload)
