from datetime import date, datetime
from pathlib import Path
from typing import Literal, Optional

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from chat_service import ChatRequest, ChatResponse, chat_with_deepseek
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
        category=CategoryOut(
            id=row["category_id"],
            name=row["category_name"],
            icon=row["category_icon"],
            color=row["category_color"],
        ),
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


def _ensure_category_exists(conn, category_id: int) -> None:
    category = conn.execute(
        "SELECT id FROM categories WHERE id = ?",
        (category_id,),
    ).fetchone()
    if category is None:
        raise HTTPException(status_code=400, detail="Category not found")


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
def list_categories() -> list[CategoryOut]:
    with get_connection() as conn:
        rows = conn.execute(
            "SELECT id, name, icon, color FROM categories ORDER BY id"
        ).fetchall()
    return [CategoryOut(**dict(row)) for row in rows]


@app.get("/api/transactions", response_model=list[TransactionOut])
def list_transactions(
    year: int = Query(..., ge=2000, le=2100),
    month: int = Query(..., ge=1, le=12),
) -> list[TransactionOut]:
    month_prefix = f"{year:04d}-{month:02d}"
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT
                t.id,
                t.title,
                t.category_id,
                c.name AS category_name,
                c.icon AS category_icon,
                c.color AS category_color,
                t.amount,
                t.type,
                t.date
            FROM transactions t
            JOIN categories c ON c.id = t.category_id
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
                t.type,
                COALESCE(SUM(t.amount), 0) AS total,
                COUNT(t.id) AS transaction_count
            FROM categories c
            LEFT JOIN transactions t
                ON t.category_id = c.id AND t.date LIKE ?
            GROUP BY c.id, c.name, c.icon, c.color, t.type
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
                "category": CategoryOut(
                    id=category_id,
                    name=row["category_name"],
                    icon=row["category_icon"],
                    color=row["category_color"],
                ),
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
        _ensure_category_exists(conn, payload.category_id)

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

        _ensure_category_exists(conn, payload.category_id)

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


@app.get("/api/chat/status")
def chat_status() -> dict:
    import os

    return {
        "configured": bool(os.getenv("DEEPSEEK_API_KEY")),
        "model": os.getenv("DEEPSEEK_MODEL", "deepseek-chat"),
    }


@app.post("/api/chat", response_model=ChatResponse)
async def chat(payload: ChatRequest) -> ChatResponse:
    return await chat_with_deepseek(payload)
