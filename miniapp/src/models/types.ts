export interface AppUser {
  id: number
  username: string
  display_name: string
  created_at: string
  is_admin: boolean
}

export interface AuthSession {
  token: string
  user: AppUser
}

export interface AuthStatus {
  has_users: boolean
  registration_open: boolean
  invite_code_required: boolean
  wechat_login_configured: boolean
}
