import type { Transaction, TransactionGroup } from '@/models/types'

export function groupTransactions(rows: Transaction[]): TransactionGroup[] {
  const map = new Map<string, Transaction[]>()
  for (const row of rows) {
    const key = row.date.slice(0, 10)
    const bucket = map.get(key)
    if (bucket) {
      bucket.push(row)
    } else {
      map.set(key, [row])
    }
  }

  const groups: TransactionGroup[] = []
  for (const [date, transactions] of map) {
    let incomeCents = 0
    let expenseCents = 0
    for (const transaction of transactions) {
      if (transaction.type === 'income') {
        incomeCents += transaction.amountCents
      } else {
        expenseCents += transaction.amountCents
      }
    }
    groups.push({ date, transactions, incomeCents, expenseCents })
  }

  groups.sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0))
  return groups
}
