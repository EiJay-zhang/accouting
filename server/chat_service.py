import os
from datetime import date
from typing import Literal, Optional

import httpx
from fastapi import HTTPException
from pydantic import BaseModel, Field

from database import get_connection

DEEPSEEK_BASE_URL = os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
DEEPSEEK_MODEL = os.getenv("DEEPSEEK_MODEL", "deepseek-chat")

SYSTEM_PROMPT = """你是「记账 App」的 AI 助手，专门帮助用户分析个人收支、理解消费结构、提供省钱与理财建议。

要求：
- 使用简洁清晰的中文回答
- 结合用户提供的记账数据进行分析，不要编造没有的数据
- 给出具体、可执行的建议
- 涉及大额决策时提醒用户仅供参考
"""


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=4000)


class ChatRequest(BaseModel):
    messages: list[ChatMessage] = Field(min_length=1, max_length=30)
    include_context: bool = True
    year: Optional[int] = None
    month: Optional[int] = None


class ChatResponse(BaseModel):
    reply: str


def _build_financial_context(year: int, month: int) -> str:
    month_prefix = f"{year:04d}-{month:02d}"
    with get_connection() as conn:
        summary_rows = conn.execute(
            """
            SELECT type, COALESCE(SUM(amount), 0) AS total
            FROM transactions
            WHERE date LIKE ?
            GROUP BY type
            """,
            (f"{month_prefix}%",),
        ).fetchall()

        category_rows = conn.execute(
            """
            SELECT
                c.name,
                t.type,
                COALESCE(SUM(t.amount), 0) AS total,
                COUNT(t.id) AS count
            FROM transactions t
            JOIN categories c ON c.id = t.category_id
            WHERE t.date LIKE ?
            GROUP BY c.name, t.type
            ORDER BY total DESC
            LIMIT 8
            """,
            (f"{month_prefix}%",),
        ).fetchall()

        recent_rows = conn.execute(
            """
            SELECT t.title, c.name, t.amount, t.type, t.date
            FROM transactions t
            JOIN categories c ON c.id = t.category_id
            WHERE t.date LIKE ?
            ORDER BY t.date DESC, t.id DESC
            LIMIT 10
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

    lines = [
        f"【用户 {year} 年 {month} 月记账数据】",
        f"- 总收入：¥{income:.2f}",
        f"- 总支出：¥{expense:.2f}",
        f"- 结余：¥{income - expense:.2f}",
    ]

    if category_rows:
        lines.append("- 分类汇总：")
        for row in category_rows:
            type_label = "收入" if row["type"] == "income" else "支出"
            lines.append(
                f"  · {row['name']}（{type_label}）¥{float(row['total']):.2f}，{row['count']} 笔"
            )

    if recent_rows:
        lines.append("- 最近交易：")
        for row in recent_rows:
            type_label = "收入" if row["type"] == "income" else "支出"
            lines.append(
                f"  · {row['date']} {row['title']} [{row['name']}] {type_label} ¥{float(row['amount']):.2f}"
            )

    if income == 0 and expense == 0 and not recent_rows:
        lines.append("- 该月暂无记账记录")

    return "\n".join(lines)


async def chat_with_deepseek(payload: ChatRequest) -> ChatResponse:
    api_key = os.getenv("DEEPSEEK_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=503,
            detail="DeepSeek API Key 未配置，请在 server/.env 中设置 DEEPSEEK_API_KEY",
        )

    today = date.today()
    year = payload.year or today.year
    month = payload.month or today.month

    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    if payload.include_context:
        messages.append(
            {
                "role": "system",
                "content": _build_financial_context(year, month),
            }
        )

    for message in payload.messages:
        messages.append({"role": message.role, "content": message.content})

    request_body = {
        "model": DEEPSEEK_MODEL,
        "messages": messages,
        "temperature": 0.7,
        "max_tokens": 1024,
    }

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                f"{DEEPSEEK_BASE_URL.rstrip('/')}/chat/completions",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json=request_body,
            )
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"无法连接 DeepSeek 服务: {exc}",
        ) from exc

    if response.status_code != 200:
        detail = response.text
        try:
            detail = response.json().get("error", {}).get("message", detail)
        except ValueError:
            pass
        raise HTTPException(
            status_code=502,
            detail=f"DeepSeek 请求失败 ({response.status_code}): {detail}",
        )

    data = response.json()
    try:
        reply = data["choices"][0]["message"]["content"].strip()
    except (KeyError, IndexError, AttributeError) as exc:
        raise HTTPException(status_code=502, detail="DeepSeek 返回格式异常") from exc

    if not reply:
        raise HTTPException(status_code=502, detail="DeepSeek 返回空内容")

    return ChatResponse(reply=reply)
