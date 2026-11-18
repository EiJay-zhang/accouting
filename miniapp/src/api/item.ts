import { request } from '@/api/http'
import type { Item, ItemStatus, ItemSummary } from '@/models/types'
import { centsFromYuan } from '@/utils/money'

interface RawItem {
  id: number
  name: string
  category_id: number | null
  category: string
  category_icon: string | null
  category_color: string | null
  amount: number
  purchase_date: string
  days_used: number
  purpose: string
  status: ItemStatus
  sold_amount: number | null
  sold_date: string | null
  held_days: number | null
  profit: number | null
  warranty_until: string | null
  note: string
}

interface RawItemSummary {
  count: number
  in_use_count: number
  total_amount: number
  daily_cost: number
  total_profit: number
}

export interface ItemQuery {
  keyword?: string
  status?: ItemStatus | null
}

export interface ItemPayload {
  [key: string]: unknown
  name: string
  category_id: number
  amount: number
  purchase_date: string
  purpose: string
  status: ItemStatus
  sold_amount: number | null
  sold_date: string | null
  warranty_until: string | null
  note: string
}

function normalizeItem(row: RawItem): Item {
  return {
    id: row.id,
    name: row.name,
    categoryId: row.category_id,
    category: row.category || '未分类',
    categoryIcon: row.category_icon,
    categoryColor: row.category_color,
    amountCents: centsFromYuan(row.amount),
    purchaseDate: row.purchase_date,
    daysUsed: row.days_used,
    purpose: row.purpose || '',
    status: row.status,
    soldAmountCents:
      row.sold_amount === null ? null : centsFromYuan(row.sold_amount),
    soldDate: row.sold_date || null,
    heldDays: row.held_days,
    profitCents: row.profit === null ? null : centsFromYuan(row.profit),
    warrantyUntil: row.warranty_until || null,
    note: row.note || '',
  }
}

export async function fetchItems(query: ItemQuery = {}): Promise<Item[]> {
  const rows = await request<RawItem[]>({
    url: '/api/items',
    query: {
      q: query.keyword?.trim() || undefined,
      status: query.status || undefined,
    },
  })
  return rows.map(normalizeItem)
}

export async function fetchItemSummary(): Promise<ItemSummary> {
  const row = await request<RawItemSummary>({
    url: '/api/items/summary',
  })
  return {
    count: row.count,
    inUseCount: row.in_use_count,
    totalAmountCents: centsFromYuan(row.total_amount),
    dailyCostCents: centsFromYuan(row.daily_cost),
    totalProfitCents: centsFromYuan(row.total_profit),
  }
}

export function createItem(payload: ItemPayload): Promise<Item> {
  return request<RawItem>({
    url: '/api/items',
    method: 'POST',
    data: payload,
  }).then(normalizeItem)
}

export function updateItem(id: number, payload: ItemPayload): Promise<Item> {
  return request<RawItem>({
    url: `/api/items/${id}`,
    method: 'PUT',
    data: payload,
  }).then(normalizeItem)
}

export function deleteItem(id: number): Promise<void> {
  return request<void>({
    url: `/api/items/${id}`,
    method: 'DELETE',
  })
}
