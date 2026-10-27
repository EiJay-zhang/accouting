import os
from datetime import date
from typing import Literal, Optional

import httpx
from fastapi import HTTPException
from pydantic import BaseModel, Field

from database import get_connection

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


class ChatResponse(BaseModel):
    reply: str
    provider: str
    model: str


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

    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    if payload.include_context:
        messages.append(
            {
                "role": "system",
                "content": _build_financial_context(year, month),
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

    return ChatResponse(reply=reply, provider=provider, model=model)
