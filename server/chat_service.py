import json
import os
import re
from datetime import date, datetime
from typing import Literal, Optional

import httpx
from fastapi import HTTPException
from pydantic import BaseModel, Field

from database import get_connection
from money import cents_to_yuan

_PROVIDER_SPECS = [
    {
        "id": "deepseek",
        "name": "DeepSeek",
        "key_envs": ["DEEPSEEK_API_KEY"],
        "base_url_env": "DEEPSEEK_BASE_URL",
        "default_base_url": "https://api.deepseek.com",
        "default_model_env": "DEEPSEEK_MODEL",
        "default_model": "deepseek-flash",
        "models": [
            {
                "id": "deepseek-flash",
                "name": "DeepSeek Flash",
                "description": "回答更快，适合日常记账问答",
                "extra": {
                    "temperature": 0.7,
                    "max_tokens": 1024,
                    "thinking": {"type": "disabled"},
                },
            },
            {
                "id": "deepseek-v4-pro",
                "name": "DeepSeek V4 Pro",
                "description": "分析更细，适合复杂的收支建议",
                "extra": {
                    "temperature": 0.7,
                    "max_tokens": 1024,
                    "thinking": {"type": "disabled"},
                },
            },
        ],
    },
    {
        "id": "kimi",
        "name": "Kimi",
        "key_envs": ["KIMI_API_KEY", "MOONSHOT_API_KEY"],
        "base_url_env": "KIMI_BASE_URL",
        "default_base_url": "https://api.moonshot.cn/v1",
        "default_model_env": "KIMI_MODEL",
        "default_model": "kimi-k2.6",
        "models": [
            {
                "id": "kimi-k2.6",
                "name": "Kimi K2.6",
                "description": "回答更快，适合日常记账问答",
                "extra": {"max_tokens": 1024, "thinking": {"type": "disabled"}},
            },
            {
                "id": "kimi-k3.1-pro",
                "name": "Kimi K3.1 Pro",
                "description": "分析更细，适合复杂的收支建议",
                "extra": {"reasoning_effort": "low", "max_tokens": 4096},
            },
        ],
    },
]
_LEGACY_MODELS = {
    "deepseek": {
        "deepseek-chat": "deepseek-flash",
        "deepseek-reasoner": "deepseek-flash",
        "deepseek-v4-flash": "deepseek-flash",
    }
}


def _provider(provider_id: str) -> Optional[dict]:
    for item in _PROVIDER_SPECS:
        if item["id"] == provider_id:
            return item
    return None


def _model_spec(spec: dict, model_id: str) -> Optional[dict]:
    for item in spec["models"]:
        if item["id"] == model_id:
            return item
    return None


def _api_key(spec: dict) -> str:
    for name in spec["key_envs"]:
        value = os.getenv(name, "").strip()
        if value:
            return value
    return ""


def provider_catalog() -> list[dict]:
    catalog = []
    for spec in _PROVIDER_SPECS:
        configured = bool(_api_key(spec))
        catalog.append(
            {
                "id": spec["id"],
                "name": spec["name"],
                "available": True,
                "configured": configured,
                "hint": "" if configured else "未配置密钥",
                "key_env": spec["key_envs"][0],
                "models": [
                    {
                        "id": item["id"],
                        "name": item["name"],
                        "description": item["description"],
                    }
                    for item in spec["models"]
                ],
            }
        )
    return catalog


def default_selection() -> tuple[str, str]:
    return resolve_selection(None, None)


def resolve_selection(provider: Optional[str], model: Optional[str]) -> tuple[str, str]:
    provider_id = (provider or "deepseek").strip() or "deepseek"
    spec = _provider(provider_id)
    if spec is None:
        raise HTTPException(status_code=400, detail="不支持的服务")

    raw = (model or "").strip() or os.getenv(spec["default_model_env"], spec["default_model"])
    raw = _LEGACY_MODELS.get(provider_id, {}).get(raw, raw)
    if _model_spec(spec, raw) is None:
        raise HTTPException(status_code=400, detail="不支持的模型")
    return provider_id, raw


SYSTEM_PROMPT = """你是「记账 App」的 AI 助手，专门帮助用户分析个人收支、理解消费结构、提供省钱与理财建议。

要求：
- 使用简洁清晰的中文回答
- 结合用户提供的记账数据进行分析，不要编造没有的数据
- 给出具体、可执行的建议
- 涉及大额决策时提醒用户仅供参考
"""

RECORD_PROMPT = """当用户明确要记一笔账时，先用一句简短中文确认，再在回答最后单独附上一个 json 代码块。除此之外不要写代码块。
```json
{"record":{"title":"午餐","amount":28,"type":"expense","category":"餐饮","date":"2026-10-28"}}
```
规则：type 只能是 income 或 expense；category 必须使用给定的分类名称；date 用 YYYY-MM-DD，用户没说日期就用今天；amount 是不含货币符号的正数。用户不是在记账时，不要输出这个 json。"""

_RECORD_BLOCK = re.compile(r"```(?:json)?\s*(\{.*?\})\s*```", re.DOTALL | re.IGNORECASE)


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=4000)


class ChatRequest(BaseModel):
    messages: list[ChatMessage] = Field(min_length=1, max_length=30)
    include_context: bool = True
    year: Optional[int] = None
    month: Optional[int] = None
    provider: Optional[str] = Field(default=None, max_length=32)
    model: Optional[str] = Field(default=None, max_length=64)


class RecordDraft(BaseModel):
    title: str
    amount: float
    type: Literal["income", "expense"]
    category_id: int
    category_name: str
    date: str


class ChatResponse(BaseModel):
    reply: str
    provider: str
    model: str
    assistant_message_id: Optional[int] = None
    proposal: Optional[RecordDraft] = None


def _record_context(user_id: int) -> str:
    today = date.today().isoformat()
    with get_connection() as conn:
        rows = conn.execute(
            "SELECT name, type FROM categories WHERE user_id = ? ORDER BY id",
            (user_id,),
        ).fetchall()
    expense = "、".join(row["name"] for row in rows if row["type"] == "expense") or "无"
    income = "、".join(row["name"] for row in rows if row["type"] == "income") or "无"
    return f"今天是 {today}。支出分类：{expense}。收入分类：{income}。\n{RECORD_PROMPT}"


def _resolve_record(record: dict, user_id: int) -> Optional[RecordDraft]:
    try:
        amount = float(record.get("amount"))
    except (TypeError, ValueError):
        return None
    if amount <= 0:
        return None
    tx_type = record.get("type")
    if tx_type not in ("income", "expense"):
        return None

    title = str(record.get("title") or "").strip()
    category_name = str(record.get("category") or "").strip()
    raw_date = str(record.get("date") or "").strip()
    try:
        parsed = datetime.fromisoformat(raw_date).date() if raw_date else date.today()
    except ValueError:
        parsed = date.today()

    with get_connection() as conn:
        rows = list(
            conn.execute(
                "SELECT id, name FROM categories WHERE type = ? AND user_id = ? ORDER BY id",
                (tx_type, user_id),
            )
        )
    if not rows:
        return None

    chosen = None
    for row in rows:
        if row["name"] == category_name:
            chosen = row
            break
    if chosen is None and category_name:
        for row in rows:
            if category_name in row["name"] or row["name"] in category_name:
                chosen = row
                break
    if chosen is None:
        chosen = rows[0]
    if not title:
        title = chosen["name"]

    return RecordDraft(
        title=title[:200],
        amount=round(amount, 2),
        type=tx_type,
        category_id=int(chosen["id"]),
        category_name=chosen["name"],
        date=parsed.isoformat(),
    )


def _extract_record(reply: str, user_id: int) -> tuple[str, Optional[RecordDraft]]:
    match = _RECORD_BLOCK.search(reply)
    if match is None:
        return reply, None
    try:
        payload = json.loads(match.group(1))
    except json.JSONDecodeError:
        return reply, None
    record = payload.get("record") if isinstance(payload, dict) else None
    if not isinstance(record, dict):
        return reply, None
    draft = _resolve_record(record, user_id)
    if draft is None:
        return reply, None
    cleaned = (reply[: match.start()] + reply[match.end() :]).strip()
    if not cleaned:
        cleaned = f"可以记下这笔：{draft.title} ¥{draft.amount:.2f}"
    return cleaned, draft


def _build_financial_context(year: int, month: int, user_id: int) -> str:
    month_prefix = f"{year:04d}-{month:02d}"
    with get_connection() as conn:
        summary_rows = conn.execute(
            """
            SELECT type, COALESCE(SUM(amount_cents), 0) AS total
            FROM transactions
            WHERE date LIKE ? AND user_id = ?
            GROUP BY type
            """,
            (f"{month_prefix}%", user_id),
        ).fetchall()

        category_rows = conn.execute(
            """
            SELECT
                c.name,
                t.type,
                COALESCE(SUM(t.amount_cents), 0) AS total,
                COUNT(t.id) AS count
            FROM transactions t
            JOIN categories c ON c.id = t.category_id
            WHERE t.date LIKE ? AND t.user_id = ?
            GROUP BY c.name, t.type
            ORDER BY total DESC
            LIMIT 8
            """,
            (f"{month_prefix}%", user_id),
        ).fetchall()

        recent_rows = conn.execute(
            """
            SELECT t.title, c.name, t.amount_cents, t.type, t.date
            FROM transactions t
            JOIN categories c ON c.id = t.category_id
            WHERE t.date LIKE ? AND t.user_id = ?
            ORDER BY t.date DESC, t.id DESC
            LIMIT 10
            """,
            (f"{month_prefix}%", user_id),
        ).fetchall()

    income = 0
    expense = 0
    for row in summary_rows:
        if row["type"] == "income":
            income = int(row["total"])
        else:
            expense = int(row["total"])
    income_yuan = cents_to_yuan(income)
    expense_yuan = cents_to_yuan(expense)

    lines = [
        f"【用户 {year} 年 {month} 月记账数据】",
        f"- 总收入：¥{income_yuan:.2f}",
        f"- 总支出：¥{expense_yuan:.2f}",
        f"- 结余：¥{cents_to_yuan(income - expense):.2f}",
    ]

    if category_rows:
        lines.append("- 分类汇总：")
        for row in category_rows:
            type_label = "收入" if row["type"] == "income" else "支出"
            lines.append(
                f"  · {row['name']}（{type_label}）¥{cents_to_yuan(int(row['total'])):.2f}，{row['count']} 笔"
            )

    if recent_rows:
        lines.append("- 最近交易：")
        for row in recent_rows:
            type_label = "收入" if row["type"] == "income" else "支出"
            lines.append(
                f"  · {row['date']} {row['title']} [{row['name']}] {type_label} ¥{cents_to_yuan(int(row['amount_cents'])):.2f}"
            )

    if income_yuan == 0 and expense_yuan == 0 and not recent_rows:
        lines.append("- 该月暂无记账记录")

    return "\n".join(lines)


async def chat_with_deepseek(payload: ChatRequest, user_id: int) -> ChatResponse:
    provider, model = resolve_selection(payload.provider, payload.model)
    spec = _provider(provider)
    model_spec = _model_spec(spec, model) if spec is not None else None
    if spec is None or model_spec is None:
        raise HTTPException(status_code=400, detail="不支持的模型")
    api_key = _api_key(spec)
    if not api_key:
        raise HTTPException(
            status_code=503,
            detail=f"{spec['name']} API Key 未配置，请在 server/.env 中设置 {spec['key_envs'][0]}",
        )

    today = date.today()
    year = payload.year or today.year
    month = payload.month or today.month

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "system", "content": _record_context(user_id)},
    ]
    if payload.include_context:
        messages.append(
            {
                "role": "system",
                "content": _build_financial_context(year, month, user_id),
            }
        )
    else:
        messages.append(
            {
                "role": "system",
                "content": (
                    "用户关闭了记账数据。这次没有提供任何账单，也不要沿用对话里出现过的金额、分类和笔数。"
                    "如果问题需要真实收支，请说明需要打开「本月账单」后再问，不要编造数字。"
                ),
            }
        )

    for message in payload.messages:
        messages.append({"role": message.role, "content": message.content})

    request_body = {"model": model, "messages": messages}
    request_body.update(model_spec.get("extra") or {})

    base_url = os.getenv(spec["base_url_env"], spec["default_base_url"]).rstrip("/")
    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(
                f"{base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json=request_body,
            )
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"无法连接 {spec['name']} 服务: {exc}",
        ) from exc

    if response.status_code != 200:
        detail = response.text
        try:
            detail = response.json().get("error", {}).get("message", detail)
        except ValueError:
            pass
        raise HTTPException(
            status_code=502,
            detail=f"{spec['name']} 请求失败 ({response.status_code}): {detail}",
        )

    data = response.json()
    try:
        reply = (data["choices"][0]["message"].get("content") or "").strip()
    except (KeyError, IndexError, AttributeError) as exc:
        raise HTTPException(status_code=502, detail=f"{spec['name']} 返回格式异常") from exc

    if not reply:
        raise HTTPException(status_code=502, detail=f"{spec['name']} 返回空内容")

    reply, proposal = _extract_record(reply, user_id)
    return ChatResponse(
        reply=reply,
        provider=provider,
        model=model,
        proposal=proposal,
    )
