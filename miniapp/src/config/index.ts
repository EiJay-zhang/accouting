const rawBaseUrl = import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:8000'

export const API_BASE_URL = rawBaseUrl.replace(/\/+$/, '')

export const STORAGE_KEYS = {
  token: 'auth_token',
  user: 'auth_user',
} as const

export const APP_VERSION = '1.0.0'
