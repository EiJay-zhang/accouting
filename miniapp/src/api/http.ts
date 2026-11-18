import { API_BASE_URL, STORAGE_KEYS } from '@/config'

type QueryValue = string | number | undefined | null

export interface RequestOptions {
  url: string
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE'
  data?: Record<string, unknown>
  query?: Record<string, QueryValue>
  auth?: boolean
}

export class ApiError extends Error {
  statusCode: number

  constructor(message: string, statusCode: number) {
    super(message)
    this.name = 'ApiError'
    this.statusCode = statusCode
  }
}

function buildUrl(path: string, query?: Record<string, QueryValue>): string {
  const pairs = Object.entries(query || {})
    .filter(([, value]) => value !== undefined && value !== null && value !== '')
    .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`)
  return `${API_BASE_URL}${path}${pairs.length ? `?${pairs.join('&')}` : ''}`
}

function handleUnauthorized(): void {
  uni.removeStorageSync(STORAGE_KEYS.token)
  uni.removeStorageSync(STORAGE_KEYS.user)
  const pages = getCurrentPages()
  const current = pages[pages.length - 1]?.route || ''
  if (!current.includes('pages/login/index')) {
    uni.reLaunch({ url: '/pages/login/index' })
  }
}

export interface UploadOptions {
  url: string
  filePath: string
  name?: string
  formData?: Record<string, string>
  auth?: boolean
}

export function upload<T>(options: UploadOptions): Promise<T> {
  return new Promise((resolve, reject) => {
    const token = uni.getStorageSync(STORAGE_KEYS.token)
    uni.uploadFile({
      url: buildUrl(options.url),
      filePath: options.filePath,
      name: options.name || 'file',
      formData: options.formData,
      timeout: 60000,
      header:
        options.auth !== false && token
          ? { Authorization: `Bearer ${token}` }
          : {},
      success: (response) => {
        const status = response.statusCode
        let payload: unknown = response.data
        if (typeof response.data === 'string') {
          try {
            payload = JSON.parse(response.data)
          } catch {
            payload = null
          }
        }
        if (status >= 200 && status < 300) {
          resolve(payload as T)
          return
        }
        if (status === 401) {
          handleUnauthorized()
        }
        const detail = (payload as { detail?: string } | null)?.detail
        reject(new ApiError(detail || `上传失败（${status}）`, status))
      },
      fail: () => {
        reject(new ApiError('网络异常，请检查网络后重试', 0))
      },
    })
  })
}

export function download(options: {
  url: string
  query?: Record<string, QueryValue>
}): Promise<string> {
  return new Promise((resolve, reject) => {
    const token = uni.getStorageSync(STORAGE_KEYS.token)
    uni.downloadFile({
      url: buildUrl(options.url, options.query),
      timeout: 60000,
      header: token ? { Authorization: `Bearer ${token}` } : {},
      success: (response) => {
        const status = response.statusCode
        if (status >= 200 && status < 300) {
          resolve(response.tempFilePath)
          return
        }
        if (status === 401) {
          handleUnauthorized()
        }
        reject(new ApiError(`下载失败（${status}）`, status))
      },
      fail: () => {
        reject(new ApiError('下载失败，请检查网络后重试', 0))
      },
    })
  })
}

export function request<T>(options: RequestOptions): Promise<T> {
  return new Promise((resolve, reject) => {
    const token = uni.getStorageSync(STORAGE_KEYS.token)
    uni.request({
      url: buildUrl(options.url, options.query),
      method: options.method || 'GET',
      data: options.data,
      timeout: 30000,
      header: {
        'Content-Type': 'application/json',
        ...(options.auth !== false && token
          ? { Authorization: `Bearer ${token}` }
          : {}),
      },
      success: (response) => {
        const status = response.statusCode
        if (status >= 200 && status < 300) {
          resolve(response.data as T)
          return
        }
        if (status === 401) {
          handleUnauthorized()
        }
        const detail = (response.data as { detail?: string } | undefined)?.detail
        reject(new ApiError(detail || `请求失败（${status}）`, status))
      },
      fail: () => {
        reject(new ApiError('网络异常，请检查网络后重试', 0))
      },
    })
  })
}
