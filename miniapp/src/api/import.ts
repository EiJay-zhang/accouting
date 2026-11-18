import { request, upload } from '@/api/http'
import type { TransactionType } from '@/models/types'

export type ImportSource = 'alipay' | 'wechat' | 'bank'

export interface ImportPreviewItem {
  external_id: string
  title: string
  amount: number
  type: TransactionType
  date: string
  category_id: number | null
  category_name: string
  matched: boolean
  counterparty: string
  duplicate: boolean
  skipped: boolean
  skip_reason: string
}

export interface ImportPreview {
  source: ImportSource
  source_label: string
  total: number
  ready_count: number
  duplicate_count: number
  skipped_count: number
  items: ImportPreviewItem[]
}

export interface ImportCommitItem {
  external_id: string
  title: string
  amount: number
  type: TransactionType
  date: string
  category_id: number
  source: ImportSource
}

export interface ImportResult {
  imported: number
  duplicates: number
}

export function previewImport(filePath: string): Promise<ImportPreview> {
  return upload<ImportPreview>({
    url: '/api/imports/preview',
    filePath,
    name: 'file',
  })
}

export function commitImport(items: ImportCommitItem[]): Promise<ImportResult> {
  return request<ImportResult>({
    url: '/api/imports/commit',
    method: 'POST',
    data: { items },
  })
}
