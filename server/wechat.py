"""微信小程序登录：用 wx.login 的 code 换取 openid。"""

import os

import httpx
from fastapi import HTTPException

_JSCODE2SESSION_URL = "https://api.weixin.qq.com/sns/jscode2session"


def _app_config() -> tuple[str, str]:
    return (
        os.environ.get("WX_APPID", "").strip(),
        os.environ.get("WX_SECRET", "").strip(),
    )


def is_configured() -> bool:
    appid, secret = _app_config()
    return bool(appid and secret)


def exchange_code(code: str) -> str:
    """返回 openid。session_key 不返回、不落库、不打日志。"""
    appid, secret = _app_config()
    if not appid or not secret:
        raise HTTPException(status_code=503, detail="微信登录未配置")

    code = (code or "").strip()
    if not code:
        raise HTTPException(status_code=400, detail="缺少登录凭证")

    try:
        response = httpx.get(
            _JSCODE2SESSION_URL,
            params={
                "appid": appid,
                "secret": secret,
                "js_code": code,
                "grant_type": "authorization_code",
            },
            timeout=10,
        )
        response.raise_for_status()
        payload = response.json()
    except (httpx.HTTPError, ValueError) as exc:
        raise HTTPException(status_code=502, detail="微信登录失败，请稍后重试") from exc

    errcode = payload.get("errcode") or 0
    if errcode:
        if errcode in (40029, 40163):
            raise HTTPException(status_code=401, detail="登录凭证已失效，请重新登录")
        if errcode == 45011:
            raise HTTPException(status_code=429, detail="操作过于频繁，请稍后再试")
        raise HTTPException(status_code=502, detail=f"微信登录失败（{errcode}）")

    openid = payload.get("openid")
    if not openid:
        raise HTTPException(status_code=502, detail="微信登录失败：未返回 openid")
    return str(openid)
