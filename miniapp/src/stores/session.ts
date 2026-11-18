import { reactive } from 'vue'

import { request } from '@/api/http'
import { STORAGE_KEYS } from '@/config'
import type { AppUser, AuthSession, AuthStatus } from '@/models/types'

export const session = reactive<{
  token: string
  user: AppUser | null
}>({
  token: '',
  user: null,
})

export function restoreSession(): boolean {
  const token = String(uni.getStorageSync(STORAGE_KEYS.token) || '')
  const user = uni.getStorageSync(STORAGE_KEYS.user)
  if (!token || !user || typeof user !== 'object') {
    return false
  }
  session.token = token
  session.user = user as AppUser
  return true
}

export function isLoggedIn(): boolean {
  return Boolean(session.token || uni.getStorageSync(STORAGE_KEYS.token))
}

function applySession(payload: AuthSession): AuthSession {
  if (!payload?.token || !payload?.user) {
    throw new Error('登录返回数据不完整')
  }
  session.token = payload.token
  session.user = payload.user
  uni.setStorageSync(STORAGE_KEYS.token, payload.token)
  uni.setStorageSync(STORAGE_KEYS.user, payload.user)
  return payload
}

export function clearSession(): void {
  session.token = ''
  session.user = null
  uni.removeStorageSync(STORAGE_KEYS.token)
  uni.removeStorageSync(STORAGE_KEYS.user)
}

export function fetchAuthStatus(): Promise<AuthStatus> {
  return request<AuthStatus>({
    url: '/api/auth/status',
    auth: false,
  })
}

export async function loginWithWechat(): Promise<AuthSession> {
  const code = await new Promise<string>((resolve, reject) => {
    uni.login({
      provider: 'weixin',
      success: (result) => {
        if (result.code) {
          resolve(result.code)
          return
        }
        reject(new Error('未获取到微信登录凭证'))
      },
      fail: () => reject(new Error('微信登录失败，请重试')),
    })
  })

  const payload = await request<AuthSession>({
    url: '/api/auth/wx-login',
    method: 'POST',
    data: { code },
    auth: false,
  })
  return applySession(payload)
}

export async function loginWithPassword(
  username: string,
  password: string,
): Promise<AuthSession> {
  const payload = await request<AuthSession>({
    url: '/api/auth/login',
    method: 'POST',
    data: { username, password },
    auth: false,
  })
  return applySession(payload)
}

export async function registerAccount(
  username: string,
  password: string,
  displayName?: string,
  inviteCode?: string,
): Promise<AuthSession> {
  const payload = await request<AuthSession>({
    url: '/api/auth/register',
    method: 'POST',
    data: {
      username,
      password,
      display_name: displayName || undefined,
      invite_code: inviteCode || undefined,
    },
    auth: false,
  })
  return applySession(payload)
}

export async function logout(): Promise<void> {
  try {
    await request<void>({
      url: '/api/auth/logout',
      method: 'POST',
    })
  } catch {
    // 本地退出优先，不阻塞用户
  }
  clearSession()
}
