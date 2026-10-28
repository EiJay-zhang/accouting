"""金额以分为整数保存，汇总时不再用浮点数相加。"""


def yuan_to_cents(value: float) -> int:
    return int(round(float(value) * 100))


def cents_to_yuan(cents: int) -> float:
    return int(cents) / 100
