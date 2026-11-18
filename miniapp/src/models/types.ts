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

export type ItemStatus = 'in_use' | 'idle' | 'sold' | 'retired'

export interface Item {
  id: number
  name: string
  categoryId: number | null
  category: string
  categoryIcon: string | null
  categoryColor: string | null
  amountCents: number
  purchaseDate: string
  daysUsed: number
  purpose: string
  status: ItemStatus
  soldAmountCents: number | null
  soldDate: string | null
  heldDays: number | null
  profitCents: number | null
  warrantyUntil: string | null
  note: string
}

export interface ItemSummary {
  count: number
  inUseCount: number
  totalAmountCents: number
  dailyCostCents: number
  totalProfitCents: number
}

export type ReportPeriod = 'week' | 'month' | 'year'

export interface CategoryReportItem {
  category: Category
  incomeCents: number
  expenseCents: number
  transactionCount: number
  budgetCents: number | null
}

export interface CategoryReport {
  period: ReportPeriod
  year: number
  month: number
  start: string
  end: string
  incomeCents: number
  expenseCents: number
  totalCents: number
  categories: CategoryReportItem[]
}

export interface TrendPoint {
  year: number
  month: number
  day: number
  label: string
  incomeCents: number
  expenseCents: number
}

export interface TrendReport {
  points: TrendPoint[]
  incomeDeltaCents: number
  expenseDeltaCents: number
}
