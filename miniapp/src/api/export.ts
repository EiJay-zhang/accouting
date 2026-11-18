import { download } from '@/api/http'

export function downloadTransactionsXlsx(): Promise<string> {
  return download({ url: '/api/exports/transactions.xlsx' })
}
