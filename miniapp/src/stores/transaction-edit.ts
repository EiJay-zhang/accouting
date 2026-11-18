import type { Transaction } from '@/models/types'

let pending: Transaction | null = null

export function setPendingEdit(transaction: Transaction | null): void {
  pending = transaction
}

export function takePendingEdit(): Transaction | null {
  const value = pending
  pending = null
  return value
}
