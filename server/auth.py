import hashlib
import hmac
import re
import secrets
import sqlite3
from datetime import datetime, timedelta
from typing import Optional

from fastapi import Header, HTTPException

from database import get_connection

_USERNAME = re.compile(r"^[\w\u4e00-\u9fff]{2,20}$")

_DEFAULT_CATEGORIES = (
    ("餐饮", "🍜", "#FF9800", "expense"),
    ("交通", "🚇", "#2196F3", "expense"),
    ("购物", "🛍️", "#E91E63", "expense"),
    ("娱乐", "🎬", "#9C27B0", "expense"),
    ("医疗", "💊", "#F44336", "expense"),
    ("教育", "📚", "#3F51B5", "expense"),
    ("住房", "🏠", "#009688", "expense"),
    ("工资", "💰", "#4CAF50", "income"),
)

_DEFAULT_TAGS = {
    ("餐饮", "expense"): ("早餐", "午餐", "晚餐", "外卖", "咖啡"),
    ("交通", "expense"): ("地铁", "公交", "打车", "加油"),
    ("购物", "expense"): ("日用品", "服饰", "数码"),
    ("娱乐", "expense"): ("电影", "游戏", "聚会"),
    ("医疗", "expense"): ("买药", "挂号", "检查"),
    ("教育", "expense"): ("书籍", "课程", "学费"),
    ("住房", "expense"): ("房租", "水电", "物业"),
    ("工资", "income"): ("月薪", "奖金", "补贴"),
}


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, 200_000)
    return f"pbkdf2_sha256$200000${salt.hex()}${digest.hex()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        algorithm, rounds, salt_hex, digest_hex = stored.split("$")
        if algorithm != "pbkdf2_sha256":
            return False
        actual = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            bytes.fromhex(salt_hex),
            int(rounds),
        )
        return hmac.compare_digest(actual, bytes.fromhex(digest_hex))
    except (TypeError, ValueError):
        return False


def _clean_username(username: str) -> str:
    cleaned = username.strip()
    if _USERNAME.fullmatch(cleaned) is None:
        raise HTTPException(status_code=400, detail="用户名需要 2-20 位，不能有空格")
    return cleaned


def _clean_password(password: str) -> str:
    if len(password) < 6 or len(password) > 64:
        raise HTTPException(status_code=400, detail="密码需要 6-64 位")
    return password


def _clean_display_name(display_name: Optional[str], username: str) -> str:
    cleaned = (display_name or "").strip() or username
    if len(cleaned) > 20:
        raise HTTPException(status_code=400, detail="昵称最多 20 个字")
    return cleaned


def _user_out(row) -> dict:
    return {
        "id": int(row["id"]),
        "username": row["username"],
        "display_name": row["display_name"],
        "created_at": row["created_at"],
    }


def _seed_account(conn, user_id: int) -> None:
    unclaimed = conn.execute(
        "SELECT COUNT(*) FROM categories WHERE user_id IS NULL"
    ).fetchone()[0]
    if unclaimed:
        conn.execute(
            "UPDATE categories SET user_id = ? WHERE user_id IS NULL",
            (user_id,),
        )
        conn.execute(
            "UPDATE transactions SET user_id = ? WHERE user_id IS NULL",
            (user_id,),
        )
        conn.execute(
            "UPDATE chat_messages SET user_id = ? WHERE user_id IS NULL",
            (user_id,),
        )
        return

    for name, icon, color, category_type in _DEFAULT_CATEGORIES:
        conn.execute(
            """
            INSERT INTO categories (user_id, name, icon, color, type)
            VALUES (?, ?, ?, ?, ?)
            """,
            (user_id, name, icon, color, category_type),
        )
    rows = conn.execute(
        "SELECT id, name, type FROM categories WHERE user_id = ?",
        (user_id,),
    ).fetchall()
    for row in rows:
        names = _DEFAULT_TAGS.get((row["name"], row["type"]), ())
        for index, tag_name in enumerate(names, start=1):
            conn.execute(
                """
                INSERT INTO tags (category_id, name, sort_order)
                VALUES (?, ?, ?)
                """,
                (row["id"], tag_name, index),
            )


def _insert_user(conn, username: str, password: str, display_name: str):
    now = datetime.now().isoformat(timespec="seconds")
    try:
        cursor = conn.execute(
            """
            INSERT INTO users (username, password_hash, display_name, created_at)
            VALUES (?, ?, ?, ?)
            """,
            (username, hash_password(password), display_name, now),
        )
    except sqlite3.IntegrityError as exc:
        raise HTTPException(status_code=400, detail="用户名已存在") from exc
    user_id = int(cursor.lastrowid)
    _seed_account(conn, user_id)
    row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    return row


_SESSION_DAYS = 30


def _open_session(conn, user_id: int) -> str:
    token = secrets.token_urlsafe(32)
    now = datetime.now()
    expires = (now + timedelta(days=_SESSION_DAYS)).isoformat(timespec="seconds")
    conn.execute(
        """
        INSERT INTO sessions (token, user_id, created_at, expires_at)
        VALUES (?, ?, ?, ?)
        """,
        (token, user_id, now.isoformat(timespec="seconds"), expires),
    )
    return token


def auth_status() -> dict:
    with get_connection() as conn:
        count = conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
    return {"has_users": bool(count)}


def register_account(username: str, password: str, display_name: Optional[str]) -> dict:
    username = _clean_username(username)
    password = _clean_password(password)
    display_name = _clean_display_name(display_name, username)
    with get_connection() as conn:
        row = _insert_user(conn, username, password, display_name)
        token = _open_session(conn, int(row["id"]))
        conn.commit()
    return {"token": token, "user": _user_out(row)}


def login_account(username: str, password: str) -> dict:
    username = username.strip()
    with get_connection() as conn:
        row = conn.execute(
            "SELECT * FROM users WHERE username = ? COLLATE NOCASE",
            (username,),
        ).fetchone()
        if row is None or not verify_password(password, row["password_hash"]):
            raise HTTPException(status_code=401, detail="用户名或密码不正确")
        token = _open_session(conn, int(row["id"]))
        conn.commit()
    return {"token": token, "user": _user_out(row)}


def logout_account(token: str) -> None:
    with get_connection() as conn:
        conn.execute("DELETE FROM sessions WHERE token = ?", (token,))
        conn.commit()


def require_user(authorization: Optional[str] = Header(default=None)) -> int:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="请先登录")
    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="请先登录")
    with get_connection() as conn:
        row = conn.execute(
            "SELECT user_id, expires_at FROM sessions WHERE token = ?",
            (token,),
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=401, detail="登录已失效，请重新登录")
        expires_at = row["expires_at"]
        expired = not expires_at or datetime.fromisoformat(expires_at) <= datetime.now()
        if expired:
            conn.execute("DELETE FROM sessions WHERE token = ?", (token,))
            conn.commit()
            raise HTTPException(status_code=401, detail="登录已过期，请重新登录")
    return int(row["user_id"])


def bearer_token(authorization: Optional[str]) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="请先登录")
    return authorization.split(" ", 1)[1].strip()


def current_profile(user_id: int) -> dict:
    with get_connection() as conn:
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=401, detail="登录已失效，请重新登录")
    return _user_out(row)


def update_profile(
    user_id: int,
    display_name: Optional[str],
    current_password: Optional[str],
    new_password: Optional[str],
) -> dict:
    with get_connection() as conn:
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=401, detail="登录已失效，请重新登录")
        name = row["display_name"]
        if display_name is not None:
            name = _clean_display_name(display_name, row["username"])
        if new_password:
            if not current_password or not verify_password(
                current_password, row["password_hash"]
            ):
                raise HTTPException(status_code=400, detail="当前密码不正确")
            password_hash = hash_password(_clean_password(new_password))
            conn.execute(
                """
                UPDATE users
                SET display_name = ?, password_hash = ?
                WHERE id = ?
                """,
                (name, password_hash, user_id),
            )
        else:
            conn.execute(
                "UPDATE users SET display_name = ? WHERE id = ?",
                (name, user_id),
            )
        conn.commit()
        updated = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    return _user_out(updated)


def list_accounts() -> list[dict]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT id, username, display_name, created_at
            FROM users
            ORDER BY id
            """
        ).fetchall()
    return [_user_out(row) for row in rows]


def create_account(username: str, password: str, display_name: Optional[str]) -> dict:
    username = _clean_username(username)
    password = _clean_password(password)
    display_name = _clean_display_name(display_name, username)
    with get_connection() as conn:
        row = _insert_user(conn, username, password, display_name)
        conn.commit()
    return _user_out(row)


def delete_account(actor_id: int, target_id: int) -> None:
    if actor_id == target_id:
        raise HTTPException(status_code=400, detail="不能删除当前登录的账号")
    with get_connection() as conn:
        row = conn.execute("SELECT id FROM users WHERE id = ?", (target_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="账号不存在")
        conn.execute("DELETE FROM sessions WHERE user_id = ?", (target_id,))
        conn.execute("DELETE FROM chat_messages WHERE user_id = ?", (target_id,))
        conn.execute("DELETE FROM transactions WHERE user_id = ?", (target_id,))
        conn.execute("DELETE FROM categories WHERE user_id = ?", (target_id,))
        conn.execute("DELETE FROM users WHERE id = ?", (target_id,))
        conn.commit()
