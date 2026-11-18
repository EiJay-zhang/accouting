import type { ReportPeriod, TransactionType } from '@/models/types'

export interface BillsFilter {
  period: ReportPeriod
  start: string
  end: string
  categoryId: number
  type: TransactionType
}

let pending: BillsFilter | null = null

export function setBillsFilter(filter: BillsFilter): void {
  pending = filter
}

export function consumeBillsFilter(): BillsFilter | null {
  const filter = pending
  pending = null
  return filter
}
