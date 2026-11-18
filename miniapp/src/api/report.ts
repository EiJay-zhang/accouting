import { request } from '@/api/http'
import type {
  Category,
  CategoryReport,
  CategoryReportItem,
  ReportPeriod,
  TrendPoint,
  TrendReport,
} from '@/models/types'
import { centsFromYuan } from '@/utils/money'

interface RawCategoryReportItem {
  category: Category
  income: number
  expense: number
  transaction_count: number
  budget: number | null
}

interface RawCategoryReport {
  period: ReportPeriod
  year: number
  month: number
  start: string
  end: string
  income: number
  expense: number
  categories: RawCategoryReportItem[]
}

interface RawTrendPoint {
  year: number
  month: number
  day: number
  label: string
  income: number
  expense: number
}

interface RawTrendReport {
  points: RawTrendPoint[]
  income_delta: number
  expense_delta: number
}

export interface ReportQuery {
  period: ReportPeriod
  year?: number
  month?: number
  anchor?: string
}

export interface BudgetPayload {
  categoryId: number
  year: number
  month: number
  amountCents: number
  scope: ReportPeriod
  anchor?: string
}

function normalizeItem(row: RawCategoryReportItem): CategoryReportItem {
  return {
    category: row.category,
    incomeCents: centsFromYuan(row.income),
    expenseCents: centsFromYuan(row.expense),
    transactionCount: row.transaction_count,
    budgetCents: row.budget === null ? null : centsFromYuan(row.budget),
  }
}

export async function fetchCategoryReport(
  query: ReportQuery,
): Promise<CategoryReport> {
  const row = await request<RawCategoryReport>({
    url: '/api/reports/categories',
    query: {
      period: query.period,
      year: query.year,
      month: query.month,
      anchor: query.anchor,
    },
  })
  const incomeCents = centsFromYuan(row.income)
  const expenseCents = centsFromYuan(row.expense)
  return {
    period: row.period,
    year: row.year,
    month: row.month,
    start: row.start,
    end: row.end,
    incomeCents,
    expenseCents,
    totalCents: incomeCents - expenseCents,
    categories: row.categories.map(normalizeItem),
  }
}

export async function fetchTrend(query: ReportQuery): Promise<TrendReport> {
  const row = await request<RawTrendReport>({
    url: '/api/reports/trend',
    query: {
      period: query.period,
      year: query.year,
      month: query.month,
      anchor: query.anchor,
    },
  })
  const points: TrendPoint[] = row.points.map((point) => ({
    year: point.year,
    month: point.month,
    day: point.day,
    label: point.label,
    incomeCents: centsFromYuan(point.income),
    expenseCents: centsFromYuan(point.expense),
  }))
  return {
    points,
    incomeDeltaCents: centsFromYuan(row.income_delta),
    expenseDeltaCents: centsFromYuan(row.expense_delta),
  }
}

export function saveBudget(payload: BudgetPayload): Promise<void> {
  return request<void>({
    url: '/api/budgets',
    method: 'PUT',
    data: {
      category_id: payload.categoryId,
      year: payload.year,
      month: payload.month,
      amount: payload.amountCents / 100,
      scope: payload.scope,
      anchor: payload.anchor,
    },
  })
}
