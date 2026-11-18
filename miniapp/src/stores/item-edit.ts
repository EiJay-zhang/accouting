import type { Item } from '@/models/types'

let pending: Item | null = null

export function setPendingItemEdit(item: Item | null): void {
  pending = item
}

export function takePendingItemEdit(): Item | null {
  const value = pending
  pending = null
  return value
}
