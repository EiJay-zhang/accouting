"""解析支付宝、微信支付和银行卡导出的 csv / xlsx。"""

from __future__ import annotations

import csv
import hashlib
import io
import re
from dataclasses import dataclass
from datetime import date, datetime

from fastapi import HTTPException
from openpyxl import load_workbook

SOURCE_LABELS = {
    "alipay": "支付宝",
    "wechat": "微信",
    "bank": "银行卡",
}

_CATEGORY_RULES = [
    ("餐饮", ["餐饮美食", "餐饮", "美食", "外卖", "饭店", "奶茶", "咖啡", "美团", "饿了么"]),
    ("交通", ["交通出行", "交通", "地铁", "公交", "滴滴", "打车", "加油", "停车", "高铁", "火车", "机票"]),
    ("购物", ["日用百货", "购物", "百货", "超市", "淘宝", "天猫", "京东", "拼多多"]),
    ("娱乐", ["娱乐", "电影", "游戏", "视频", "音乐"]),
    ("医疗", ["医疗", "医院", "药店", "体检", "挂号"]),
    ("教育", ["教育", "培训", "学费", "课程", "书籍"]),
    ("住房", ["住房", "房租", "租金", "物业", "水电", "燃气", "电费", "水费"]),
    ("工资", ["工资", "薪资", "薪酬", "代发"]),
]


@dataclass
class ParsedBill:
    source: str
    external_id: str
    title: str
    amount: float
    tx_type: str
    date: str
    hint: str
    counterparty: str
    skipped: bool
    skip_reason: str


def parse_bill(content: bytes, filename: str, source: str | None = None) -> tuple[str, list[ParsedBill]]:
    if not content:
        raise HTTPException(status_code=400, detail="文件是空的")
    if len(content) > 8 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="文件不能超过 8MB")

    rows = _read_rows(content, filename)
    header_index, header = _find_header(rows)
    if header is None or header_index is None:
        raise HTTPException(
            status_code=400,
            detail="没有找到账单表头。请使用支付宝、微信或银行卡导出的 csv 或 xlsx",
        )

    detected = _detect_source(header, rows[:header_index])
    chosen = source or detected
    if chosen not in SOURCE_LABELS:
        raise HTTPException(status_code=400, detail="不支持的账单来源")
    if source and source != detected and detected is not None:
        # 用户指定的来源优先，但表头必须能对上该来源。
        chosen = source

    if chosen == "bank":
        bills = _parse_bank(rows, header_index, header)
    else:
        bills = _parse_wallet(rows, header_index, header, chosen)

    if not bills:
        raise HTTPException(status_code=400, detail="文件里没有可识别的账单记录")
    return chosen, bills


def suggest_category(
    hint: str,
    tx_type: str,
    categories: list[tuple[int, str, str]],
) -> tuple[int | None, str, bool]:
    same_type = [item for item in categories if item[2] == tx_type]
    text = hint or ""
    for name, keywords in _CATEGORY_RULES:
        if any(word and word in text for word in keywords):
            for category_id, category_name, _ in same_type:
                if category_name == name:
                    return category_id, category_name, True
    for category_id, category_name, _ in same_type:
        if category_name and category_name in text:
            return category_id, category_name, True
    if same_type:
        return same_type[0][0], same_type[0][1], False
    return None, "", False


def _read_rows(content: bytes, filename: str) -> list[list[str]]:
    name = filename.lower()
    if name.endswith(".xlsx") or content[:2] == b"PK":
        try:
            return _read_xlsx(content)
        except Exception as exc:
            if name.endswith(".xlsx") or content[:2] == b"PK":
                raise HTTPException(status_code=400, detail="无法读取 Excel 文件") from exc
    return _read_csv(content)


def _read_xlsx(content: bytes) -> list[list[str]]:
    workbook = load_workbook(io.BytesIO(content), read_only=True, data_only=True)
    try:
        sheet = workbook.active
        rows = []
        for row in sheet.iter_rows(values_only=True):
            rows.append([_cell_text(value) for value in row])
        return rows
    finally:
        workbook.close()


def _read_csv(content: bytes) -> list[list[str]]:
    text = _decode_text(content)
    best: list[list[str]] = []
    for delimiter in (",", "\t", ";"):
        rows = [
            [cell.strip() for cell in row]
            for row in csv.reader(io.StringIO(text), delimiter=delimiter)
        ]
        if _find_header(rows)[0] is not None:
            return rows
        if len(rows) > len(best):
            best = rows
    return best


def _decode_text(content: bytes) -> str:
    for encoding in ("utf-8-sig", "utf-8", "gb18030"):
        try:
            return content.decode(encoding)
        except UnicodeDecodeError:
            continue
    raise HTTPException(status_code=400, detail="无法识别文件编码，请另存为 csv 或 xlsx")


def _cell_text(value) -> str:
    if value is None:
        return ""
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d %H:%M:%S")
    if isinstance(value, date):
        return value.strftime("%Y-%m-%d")
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value).strip()


def _norm_header(value: str) -> str:
    text = value.replace("\ufeff", "").strip()
    text = text.replace(" ", "").replace("\u3000", "")
    return text.replace("（", "(").replace("）", ")")


def _find_header(rows: list[list[str]]) -> tuple[int | None, list[str] | None]:
    amount_names = {
        "金额",
        "金额(元)",
        "交易金额",
        "支出金额",
        "收入金额",
        "借方发生额",
        "贷方发生额",
        "借方金额",
        "贷方金额",
    }
    for index, row in enumerate(rows[:40]):
        header = [_norm_header(cell) for cell in row]
        if not any(header):
            continue
        has_date = any(name in header for name in ("交易时间", "交易日期", "记账日期"))
        has_amount = any(name in header for name in amount_names) or any(
            cell.startswith("金额") for cell in header
        )
        if has_date and has_amount:
            return index, header
    return None, None


def _detect_source(header: list[str], preamble: list[list[str]]) -> str | None:
    blob = "\n".join(" ".join(row) for row in preamble)
    if "交易订单号" in header or "支付宝" in blob:
        return "alipay"
    if "微信支付" in blob or ("交易单号" in header and "当前状态" in header):
        return "wechat"
    if any(name in header for name in ("支出金额", "收入金额", "借方发生额", "贷方发生额", "借方金额", "贷方金额", "交易金额", "流水号")):
        return "bank"
    if "收/支" in header and any(cell.startswith("金额") for cell in header):
        return "alipay"
    return None


def _parse_wallet(
    rows: list[list[str]],
    header_index: int,
    header: list[str],
    source: str,
) -> list[ParsedBill]:
    time_at = _column(header, "交易时间")
    direction_at = _column(header, "收/支")
    amount_at = _column_startswith(header, "金额")
    title_at = _first_column(header, "商品说明", "商品", "交易对方")
    party_at = _column(header, "交易对方")
    status_at = _first_column(header, "交易状态", "当前状态")
    id_at = _first_column(header, "交易订单号", "交易单号")
    category_at = _first_column(header, "交易分类", "交易类型")
    if time_at is None or direction_at is None or amount_at is None:
        raise HTTPException(status_code=400, detail=f"这份文件缺少{SOURCE_LABELS[source]}账单需要的列")

    bills = []
    for row in rows[header_index + 1 :]:
        if _is_blank(row) or _is_repeated_header(row):
            continue
        direction = _cell(row, direction_at)
        status = _cell(row, status_at)
        title = _cell(row, title_at) or _cell(row, party_at) or "导入账单"
        counterparty = _cell(row, party_at)
        raw_category = _cell(row, category_at)
        signed = _parse_amount(_cell(row, amount_at))
        tx_date = _parse_date(_cell(row, time_at))
        external_id = _cell(row, id_at)
        hint = " ".join(part for part in (raw_category, title, counterparty) if part)

        skipped, reason, tx_type = _wallet_direction(direction, status, title)
        if signed is None or signed == 0 or tx_date is None:
            skipped = True
            reason = reason or "金额或日期无法识别"
            tx_type = tx_type or "expense"
        amount = abs(signed or 0)
        if not external_id:
            external_id = _fallback_id(source, tx_date or "", tx_type, amount, title, counterparty)
        bills.append(
            ParsedBill(
                source=source,
                external_id=external_id[:80],
                title=title[:200],
                amount=amount if amount > 0 else 0.01,
                tx_type=tx_type or "expense",
                date=tx_date or "1970-01-01",
                hint=hint,
                counterparty=counterparty,
                skipped=skipped or amount <= 0,
                skip_reason=reason,
            )
        )
    return bills


def _parse_bank(rows: list[list[str]], header_index: int, header: list[str]) -> list[ParsedBill]:
    date_at = _first_column(header, "交易日期", "记账日期", "交易时间")
    out_at = _first_column(header, "支出金额", "借方发生额", "借方金额", "转出金额")
    in_at = _first_column(header, "收入金额", "贷方发生额", "贷方金额", "转入金额")
    amount_at = _first_column(header, "交易金额", "金额")
    direction_at = _first_column(header, "收/支", "收支", "借贷标志", "借贷", "交易方向")
    title_at = _first_column(header, "摘要", "交易摘要", "用途", "交易说明", "备注")
    party_at = _first_column(header, "对方户名", "对方名称", "交易对方", "对方账号")
    id_at = _first_column(header, "流水号", "交易流水号", "凭证号", "交易单号")
    if date_at is None or (out_at is None and in_at is None and amount_at is None):
        raise HTTPException(status_code=400, detail="这份文件缺少银行卡账单需要的日期或金额列")

    bills = []
    for row in rows[header_index + 1 :]:
        if _is_blank(row) or _is_repeated_header(row):
            continue
        title = _cell(row, title_at) or _cell(row, party_at) or "银行卡交易"
        counterparty = _cell(row, party_at)
        tx_date = _parse_date(_cell(row, date_at))
        external_id = _cell(row, id_at)
        skipped = False
        reason = ""
        tx_type = "expense"
        amount = 0.0

        outflow = _parse_amount(_cell(row, out_at)) if out_at is not None else None
        inflow = _parse_amount(_cell(row, in_at)) if in_at is not None else None
        if (outflow or 0) > 0:
            tx_type = "expense"
            amount = abs(outflow or 0)
        elif (inflow or 0) > 0:
            tx_type = "income"
            amount = abs(inflow or 0)
        elif amount_at is not None:
            signed = _parse_amount(_cell(row, amount_at))
            direction = _cell(row, direction_at)
            if signed is None or signed == 0:
                skipped = True
                reason = "金额无法识别"
            else:
                mapped = _direction_type(direction)
                if mapped:
                    tx_type = mapped
                    amount = abs(signed)
                elif signed < 0:
                    tx_type = "expense"
                    amount = abs(signed)
                elif direction == "" and signed > 0:
                    skipped = True
                    reason = "无法判断收入还是支出"
                    amount = abs(signed)
                else:
                    tx_type = "income" if signed > 0 else "expense"
                    amount = abs(signed)
        else:
            skipped = True
            reason = "金额为空"

        if tx_date is None:
            skipped = True
            reason = reason or "日期无法识别"
            tx_date = "1970-01-01"
        if amount <= 0:
            skipped = True
            reason = reason or "金额为空"
            amount = 0.01
        if not external_id:
            external_id = _fallback_id("bank", tx_date, tx_type, amount, title, counterparty)
        bills.append(
            ParsedBill(
                source="bank",
                external_id=external_id[:80],
                title=title[:200],
                amount=round(amount, 2),
                tx_type=tx_type,
                date=tx_date,
                hint=" ".join(part for part in (title, counterparty) if part),
                counterparty=counterparty,
                skipped=skipped,
                skip_reason=reason,
            )
        )
    return bills


def _wallet_direction(direction: str, status: str, title: str) -> tuple[bool, str, str | None]:
    text = f"{status} {title}"
    if any(word in status for word in ("关闭", "失败")):
        return True, "交易未成功", None
    if "不计收支" in direction or direction in {"/", "-", ""}:
        if "退款" in text:
            return False, "", "income"
        return True, "不计收支", None
    if "退款" in text and "支出" not in direction:
        return False, "", "income"
    mapped = _direction_type(direction)
    if mapped is None:
        return True, "无法判断收入还是支出", None
    return False, "", mapped


def _direction_type(direction: str) -> str | None:
    if any(word in direction for word in ("支出", "借方", "转出")) or direction in {"借", "支"}:
        return "expense"
    if any(word in direction for word in ("收入", "贷方", "转入")) or direction in {"贷", "收"}:
        return "income"
    return None


def _column(header: list[str], name: str) -> int | None:
    try:
        return header.index(name)
    except ValueError:
        return None


def _first_column(header: list[str], *names: str) -> int | None:
    for name in names:
        index = _column(header, name)
        if index is not None:
            return index
    return None


def _column_startswith(header: list[str], prefix: str) -> int | None:
    for index, name in enumerate(header):
        if name.startswith(prefix):
            return index
    return None


def _cell(row: list[str], index: int | None) -> str:
    if index is None or index >= len(row):
        return ""
    return row[index].strip()


def _is_blank(row: list[str]) -> bool:
    return not any(cell.strip() for cell in row)


def _is_repeated_header(row: list[str]) -> bool:
    cells = [_norm_header(cell) for cell in row]
    return "交易时间" in cells or "交易日期" in cells


def _parse_amount(value: str) -> float | None:
    if not value:
        return None
    cleaned = value.replace("¥", "").replace("￥", "").replace(",", "").replace("，", "")
    cleaned = cleaned.replace("元", "").replace(" ", "").replace("\u3000", "")
    if cleaned in {"", "-", "--", "/"}:
        return None
    try:
        return round(float(cleaned), 2)
    except ValueError:
        return None


def _parse_date(value: str) -> str | None:
    text = value.strip().replace("/", "-").replace(".", "-")
    if not text:
        return None
    head = text.split()[0]
    if re.fullmatch(r"\d{8}", head):
        return f"{head[:4]}-{head[4:6]}-{head[6:8]}"
    for candidate in (text, head):
        try:
            return datetime.fromisoformat(candidate).date().isoformat()
        except ValueError:
            continue
    for fmt, size in (("%Y-%m-%d %H:%M:%S", 19), ("%Y-%m-%d %H:%M", 16), ("%Y-%m-%d", 10)):
        try:
            return datetime.strptime(text[:size], fmt).date().isoformat()
        except ValueError:
            continue
    return None


def _fallback_id(source: str, tx_date: str, tx_type: str, amount: float, title: str, counterparty: str) -> str:
    raw = "|".join([source, tx_date, tx_type, f"{amount:.2f}", title, counterparty])
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()[:32]
