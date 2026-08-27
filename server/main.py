from datetime import date, datetime
from typing import Literal, Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from database import get_connection, init_db

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


class CreateTransactionIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    category_id: int
    amount: float = Field(gt=0)
    type: Literal["income", "expense"]
    date: Optional[str] = None


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


@app.on_event("startup")
def on_startup() -> None:
    init_db()


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


@app.post("/api/transactions", response_model=TransactionOut, status_code=201)
def create_transaction(payload: CreateTransactionIn) -> TransactionOut:
    tx_date = payload.date or date.today().isoformat()
    try:
        datetime.fromisoformat(tx_date)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid date format") from exc

    with get_connection() as conn:
        category = conn.execute(
            "SELECT id FROM categories WHERE id = ?",
            (payload.category_id,),
        ).fetchone()
        if category is None:
            raise HTTPException(status_code=400, detail="Category not found")

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

        row = conn.execute(
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
            WHERE t.id = ?
            """,
            (tx_id,),
        ).fetchone()

    return _row_to_transaction(dict(row))
