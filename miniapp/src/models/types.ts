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

export type TransactionType = 'income' | 'expense'

export interface Category {
  id: number
  name: string
  icon: string
  color: string
  type: TransactionType
}

export interface CategoryTag {
  id: number
  category_id: number
  name: string
  sort_order: number
}

export interface Transaction {
  id: number
  title: string
  category: Category
  amountCents: number
  type: TransactionType
  date: string
  tags: CategoryTag[]
}

export interface TransactionGroup {
  date: string
  transactions: Transaction[]
  incomeCents: number
  expenseCents: number
}

export interface MonthlySummary {
  year: number
  month: number
  incomeCents: number
  expenseCents: number
  totalCents: number
}
