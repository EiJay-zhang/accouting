import { request } from '@/api/http'
import type {
  Category,
  CategoryTag,
  MonthlySummary,
  Transaction,
  TransactionType,
} from '@/models/types'
import { centsFromYuan } from '@/utils/money'

interface RawTransaction {
  id: number
  title: string
  category: Category
  amount: number
  type: TransactionType
  date: string
  tags?: CategoryTag[]
}

interface RawSummary {
  year: number
  month: number
  income: number
  expense: number
  total: number
}

export interface TransactionQuery {
  year: number
  month: number
  keyword?: string
  categoryId?: number
  type?: TransactionType
  start?: string
  end?: string
}

export type TransactionPayload = {
  title: string
  category_id: number
  amount: number
  type: TransactionType
  date: string
  tag_ids: number[]
}

function normalize(row: RawTransaction): Transaction {
  return {
    ...row,
    amountCents: centsFromYuan(row.amount),
    tags: row.tags || [],
  }
}

export function fetchCategories(type?: TransactionType): Promise<Category[]> {
  return request<Category[]>({
    url: '/api/categories',
    query: { type },
  })
}

export function fetchTags(categoryId?: number): Promise<CategoryTag[]> {
  return request<CategoryTag[]>({
    url: '/api/tags',
    query: { category_id: categoryId },
  })
}

export async function fetchTransactions(
  query: TransactionQuery,
): Promise<Transaction[]> {
  const rows = await request<RawTransaction[]>({
    url: '/api/transactions',
    query: {
      year: query.year,
      month: query.month,
      q: query.keyword,
      category_id: query.categoryId,
      type: query.type,
      start: query.start,
      end: query.end,
    },
  })
  return rows.map(normalize)
}

export async function fetchSummary(
  year: number,
  month: number,
): Promise<MonthlySummary> {
  const row = await request<RawSummary>({
    url: '/api/transactions/summary',
    query: { year, month },
  })
  return {
    year: row.year,
    month: row.month,
    incomeCents: centsFromYuan(row.income),
    expenseCents: centsFromYuan(row.expense),
    totalCents: centsFromYuan(row.total),
  }
}

export function createTransaction(
  payload: TransactionPayload,
): Promise<Transaction> {
  return request<RawTransaction>({
    url: '/api/transactions',
    method: 'POST',
    data: payload,
  }).then(normalize)
}

export function updateTransaction(
  id: number,
  payload: TransactionPayload,
): Promise<Transaction> {
  return request<RawTransaction>({
    url: `/api/transactions/${id}`,
    method: 'PUT',
    data: payload,
  }).then(normalize)
}

export function deleteTransaction(id: number): Promise<void> {
  return request<void>({
    url: `/api/transactions/${id}`,
    method: 'DELETE',
  })
}

export interface CategoryPayload {
  [key: string]: unknown
  name: string
  icon: string
  color: string
  type: TransactionType
}

export interface CategoryUpdatePayload {
  [key: string]: unknown
  name: string
  icon: string
  color: string
}

export function createCategory(payload: CategoryPayload): Promise<Category> {
  return request<Category>({
    url: '/api/categories',
    method: 'POST',
    data: payload,
  })
}

export function updateCategory(
  id: number,
  payload: CategoryUpdatePayload,
): Promise<Category> {
  return request<Category>({
    url: `/api/categories/${id}`,
    method: 'PUT',
    data: payload,
  })
}

export function deleteCategory(id: number): Promise<void> {
  return request<void>({
    url: `/api/categories/${id}`,
    method: 'DELETE',
  })
}

export function createTag(categoryId: number, name: string): Promise<CategoryTag> {
  return request<CategoryTag>({
    url: '/api/tags',
    method: 'POST',
    data: { category_id: categoryId, name },
  })
}

export function updateTag(id: number, name: string): Promise<CategoryTag> {
  return request<CategoryTag>({
    url: `/api/tags/${id}`,
    method: 'PUT',
    data: { name },
  })
}

export function deleteTag(id: number): Promise<void> {
  return request<void>({
    url: `/api/tags/${id}`,
    method: 'DELETE',
  })
}
