<script setup lang="ts">
import { computed, ref } from 'vue'

import { commitImport, previewImport } from '@/api/import'
import type { ImportPreview, ImportPreviewItem } from '@/api/import'
import { fetchCategories } from '@/api/transaction'
import type { Category, TransactionType } from '@/models/types'
import { errorMessage } from '@/utils/error'
import { formatYuan } from '@/utils/money'

interface Draft {
  item: ImportPreviewItem
  checked: boolean
  categoryId: number | null
  categoryName: string
}

interface PickedFile {
  path: string
  name: string
}

const preview = ref<ImportPreview | null>(null)
const drafts = ref<Draft[]>([])
const categories = ref<Category[]>([])
const busy = ref(false)
const error = ref('')
const pickedName = ref('')

const pickerOpen = ref(false)
const pickerIndex = ref<number | null>(null)

const selectedCount = computed(
  () => drafts.value.filter((draft) => draft.checked).length,
)

const pickerOptions = computed<Category[]>(() => {
  const index = pickerIndex.value
  if (index === null) {
    return []
  }
  const draft = drafts.value[index]
  if (!draft) {
    return []
  }
  return categories.value.filter(
    (category) => category.type === draft.item.type,
  )
})

const pickerCurrentId = computed(() => {
  const index = pickerIndex.value
  return index === null ? null : drafts.value[index]?.categoryId ?? null
})

function canImport(item: ImportPreviewItem): boolean {
  return !item.skipped && !item.duplicate && item.category_id !== null
}

async function loadCategories(): Promise<void> {
  try {
    categories.value = await fetchCategories()
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  }
}

void loadCategories()

function chooseFile(): Promise<PickedFile | null> {
  return new Promise((resolve) => {
    // #ifdef H5
    uni.chooseFile({
      count: 1,
      extension: ['.csv', '.xlsx'],
      success: (result) => {
        const path = result.tempFilePaths?.[0]
        const files = result.tempFiles as unknown as
          | Array<{ name?: string }>
          | undefined
        const name = files?.[0]?.name || '账单文件'
        resolve(path ? { path, name } : null)
      },
      fail: () => resolve(null),
    })
    // #endif

    // #ifdef MP-WEIXIN
    uni.chooseMessageFile({
      count: 1,
      type: 'file',
      extension: ['csv', 'xlsx'],
      success: (result) => {
        const file = result.tempFiles?.[0]
        resolve(file ? { path: file.path, name: file.name } : null)
      },
      fail: () => resolve(null),
    })
    // #endif
  })
}

async function handlePick(): Promise<void> {
  if (busy.value) {
    return
  }
  const file = await chooseFile()
  if (!file) {
    return
  }
  pickedName.value = file.name
  busy.value = true
  error.value = ''
  try {
    const result = await previewImport(file.path)
    preview.value = result
    drafts.value = result.items.map((item) => ({
      item,
      checked: canImport(item),
      categoryId: item.category_id,
      categoryName: item.category_name,
    }))
  } catch (err) {
    preview.value = null
    drafts.value = []
    error.value = errorMessage(err)
  } finally {
    busy.value = false
  }
}

function toggleDraft(index: number): void {
  const draft = drafts.value[index]
  if (!draft || !canImport(draft.item) || busy.value) {
    return
  }
  draft.checked = !draft.checked
}

function draftNote(draft: Draft): string {
  const item = draft.item
  if (item.skipped) {
    return item.skip_reason || '已跳过'
  }
  if (item.duplicate) {
    return '已导入过'
  }
  const name = draft.categoryName || '未分类'
  return item.matched ? name : `${name}（未识别）`
}

function openPicker(index: number): void {
  const draft = drafts.value[index]
  if (!draft || !canImport(draft.item) || busy.value) {
    return
  }
  const options = categories.value.filter(
    (category) => category.type === draft.item.type,
  )
  if (!options.length) {
    uni.showToast({
      title: draft.item.type === 'income' ? '还没有收入分类' : '还没有支出分类',
      icon: 'none',
    })
    return
  }
  pickerIndex.value = index
  pickerOpen.value = true
}

function closePicker(): void {
  pickerOpen.value = false
  pickerIndex.value = null
}

function selectCategory(category: Category): void {
  const index = pickerIndex.value
  if (index === null) {
    return
  }
  const draft = drafts.value[index]
  if (draft) {
    draft.categoryId = category.id
    draft.categoryName = category.name
    draft.checked = true
  }
  closePicker()
}

async function handleCommit(): Promise<void> {
  const current = preview.value
  if (!current || busy.value) {
    return
  }
  const selected = drafts.value.filter(
    (draft) => draft.checked && draft.categoryId !== null,
  )
  if (!selected.length) {
    uni.showToast({ title: '请至少选择一笔账单', icon: 'none' })
    return
  }
  busy.value = true
  try {
    const result = await commitImport(
      selected.map((draft) => ({
        external_id: draft.item.external_id,
        title: draft.item.title,
        amount: draft.item.amount,
        type: draft.item.type,
        date: draft.item.date,
        category_id: draft.categoryId as number,
        source: current.source,
      })),
    )
    uni.showToast({
      title: `已导入 ${result.imported} 笔，跳过重复 ${result.duplicates} 笔`,
      icon: 'none',
      duration: 2000,
    })
    setTimeout(() => {
      uni.navigateBack()
    }, 800)
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  } finally {
    busy.value = false
  }
}

function resetPreview(): void {
  preview.value = null
  drafts.value = []
  error.value = ''
  pickedName.value = ''
}
</script>

<template>
  <view class="import">
    <view v-if="!preview" class="picker">
      <text class="picker__intro">
        选择支付宝、微信或银行卡导出的 CSV / XLSX 文件，系统会自动识别来源，并按订单号跳过已导入的记录。
      </text>

      <view class="hint-card">
        <text class="hint-card__title">支付宝</text>
        <text class="hint-card__body">
          账单里导出交易流水，选择 CSV 或 XLSX。不计收支和交易关闭的记录会跳过。
        </text>
      </view>
      <view class="hint-card">
        <text class="hint-card__title">微信</text>
        <text class="hint-card__body">
          钱包账单中下载账单明细。支付成功的收支会导入，转账等不计收支的记录会跳过。
        </text>
      </view>
      <view class="hint-card">
        <text class="hint-card__title">银行卡</text>
        <text class="hint-card__body">
          使用银行 App 导出的交易明细，需要包含交易日期和收支金额。
        </text>
      </view>

      <!-- #ifdef MP-WEIXIN -->
      <text class="picker__note">
        小程序只能从微信聊天或收藏中选择文件，请先把账单文件发送到任意聊天。
      </text>
      <!-- #endif -->

      <text v-if="error" class="picker__error">{{ error }}</text>

      <button class="primary-btn" :loading="busy" :disabled="busy" @tap="handlePick">
        {{ busy ? '解析中…' : '选择文件' }}
      </button>
    </view>

    <view v-else class="preview">
      <view class="preview__header">
        <text class="preview__title">
          识别为{{ preview.source_label }}，共 {{ preview.total }} 条
        </text>
        <text class="preview__subtitle">
          可导入 {{ preview.ready_count }} 笔，重复 {{ preview.duplicate_count }} 笔，跳过
          {{ preview.skipped_count }} 笔。点分类可以改归类。
        </text>
        <text v-if="pickedName" class="preview__file">{{ pickedName }}</text>
      </view>

      <view class="preview__list">
        <view v-for="(draft, index) in drafts" :key="draft.item.external_id" class="row">
          <view
            class="row__check"
            :class="{
              'row__check--on': draft.checked,
              'row__check--disabled': !canImport(draft.item),
            }"
            @tap="toggleDraft(index)"
          >
            <text v-if="draft.checked" class="row__tick">✓</text>
          </view>

          <view class="row__main">
            <text class="row__title">{{ draft.item.title }}</text>
            <view class="row__meta">
              <text class="row__date">{{ draft.item.date }}</text>
              <text class="row__note">{{ draftNote(draft) }}</text>
            </view>
          </view>

          <view v-if="canImport(draft.item)" class="row__category" @tap="openPicker(index)">
            <text class="row__category-text">{{ draft.categoryName || '选分类' }}</text>
          </view>

          <text
            class="row__amount"
            :class="draft.item.type === 'income' ? 'row__amount--income' : 'row__amount--expense'"
          >
            {{ draft.item.type === 'income' ? '+' : '-' }}{{ formatYuan(draft.item.amount * 100) }}
          </text>
        </view>
      </view>

      <view class="footer">
        <button class="footer__reset" :disabled="busy" @tap="resetPreview">重新选择</button>
        <button
          class="footer__submit"
          :loading="busy"
          :disabled="busy || selectedCount === 0"
          @tap="handleCommit"
        >
          导入 {{ selectedCount }} 笔
        </button>
      </view>
    </view>

    <view v-if="pickerOpen" class="sheet-mask" @tap="closePicker">
      <view class="sheet" @tap.stop>
        <view class="sheet__header">
          <text class="sheet__title">选择分类</text>
          <text class="sheet__close" @tap="closePicker">关闭</text>
        </view>
        <scroll-view scroll-y class="sheet__body">
          <view
            v-for="category in pickerOptions"
            :key="category.id"
            class="sheet__item"
            @tap="selectCategory(category)"
          >
            <text class="sheet__icon">{{ category.icon }}</text>
            <text class="sheet__name">{{ category.name }}</text>
            <text v-if="category.id === pickerCurrentId" class="sheet__check">✓</text>
          </view>
        </scroll-view>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.import {
  min-height: 100vh;
  padding: 24rpx 40rpx calc(40rpx + env(safe-area-inset-bottom));
  box-sizing: border-box;
}

.picker {
  display: flex;
  flex-direction: column;

  &__intro {
    font-size: 26rpx;
    line-height: 1.6;
    color: var(--color-text-secondary);
  }

  &__note {
    margin-top: 24rpx;
    font-size: 24rpx;
    line-height: 1.6;
    color: var(--color-text-tertiary);
  }

  &__error {
    margin-top: 24rpx;
    font-size: 26rpx;
    line-height: 1.6;
    color: var(--color-expense);
  }

  .primary-btn {
    margin-top: 40rpx;
  }
}

.hint-card {
  display: flex;
  flex-direction: column;
  margin-top: 20rpx;
  padding: 28rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);

  &__title {
    font-size: 28rpx;
    font-weight: 600;
    color: var(--color-text);
  }

  &__body {
    margin-top: 8rpx;
    font-size: 24rpx;
    line-height: 1.6;
    color: var(--color-text-tertiary);
  }
}

.primary-btn {
  width: 100%;
  height: 96rpx;
  font-size: 30rpx;
  font-weight: 600;
  line-height: 96rpx;
  color: #ffffff;
  background: linear-gradient(135deg, #6366f1 0%, #4338ca 100%);
  border-radius: var(--radius-control);
  box-shadow: 0 14rpx 32rpx rgba(67, 56, 202, 0.24);

  &::after {
    border: none;
  }

  &[disabled] {
    color: rgba(255, 255, 255, 0.82);
    background: linear-gradient(135deg, #a5b4fc 0%, #818cf8 100%);
    box-shadow: none;
  }
}

.preview {
  display: flex;
  flex-direction: column;
  min-height: calc(100vh - 64rpx - env(safe-area-inset-bottom));
  padding-bottom: 140rpx;
  box-sizing: border-box;

  &__header {
    display: flex;
    flex-direction: column;
  }

  &__title {
    font-size: 30rpx;
    font-weight: 700;
    color: var(--color-text);
  }

  &__subtitle {
    margin-top: 8rpx;
    font-size: 24rpx;
    line-height: 1.5;
    color: var(--color-text-tertiary);
  }

  &__file {
    margin-top: 8rpx;
    font-size: 22rpx;
    color: var(--color-text-tertiary);
  }

  &__list {
    display: flex;
    flex: 1;
    flex-direction: column;
    margin-top: 20rpx;
  }
}

.row {
  display: flex;
  align-items: center;
  margin-bottom: 16rpx;
  padding: 22rpx 24rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-control);
  box-shadow: var(--shadow-card);

  &__check {
    display: flex;
    flex-shrink: 0;
    align-items: center;
    justify-content: center;
    width: 40rpx;
    height: 40rpx;
    margin-right: 18rpx;
    border: 2rpx solid var(--color-border);
    border-radius: 10rpx;

    &--on {
      background-color: var(--color-primary);
      border-color: var(--color-primary);
    }

    &--disabled {
      background-color: var(--color-surface-muted);
      border-color: var(--color-border);
    }
  }

  &__tick {
    font-size: 24rpx;
    line-height: 1;
    color: #ffffff;
  }

  &__main {
    display: flex;
    flex: 1;
    flex-direction: column;
    min-width: 0;
  }

  &__title {
    overflow: hidden;
    font-size: 28rpx;
    font-weight: 600;
    color: var(--color-text);
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  &__meta {
    display: flex;
    align-items: center;
    margin-top: 6rpx;
  }

  &__date {
    font-size: 22rpx;
    color: var(--color-text-tertiary);
  }

  &__note {
    margin-left: 12rpx;
    overflow: hidden;
    font-size: 22rpx;
    color: var(--color-text-tertiary);
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  &__category {
    flex-shrink: 0;
    margin-left: 12rpx;
    padding: 6rpx 16rpx;
    background-color: var(--color-primary-soft);
    border-radius: 999rpx;
  }

  &__category-text {
    font-size: 22rpx;
    color: var(--color-primary-deep);
  }

  &__amount {
    flex-shrink: 0;
    margin-left: 16rpx;
    font-size: 28rpx;
    font-weight: 600;

    &--income {
      color: var(--color-income);
    }

    &--expense {
      color: var(--color-expense);
    }
  }
}

.footer {
  position: fixed;
  right: 0;
  bottom: 0;
  left: 0;
  display: flex;
  align-items: center;
  padding: 20rpx 40rpx calc(20rpx + env(safe-area-inset-bottom));
  background-color: var(--color-bg);
  border-top: 1rpx solid var(--color-border);

  &__reset {
    width: 200rpx;
    height: 88rpx;
    font-size: 26rpx;
    line-height: 88rpx;
    color: var(--color-text-secondary);
    background-color: var(--color-surface);
    border: 2rpx solid var(--color-border);
    border-radius: var(--radius-control);

    &::after {
      border: none;
    }
  }

  &__submit {
    flex: 1;
    height: 88rpx;
    margin-left: 20rpx;
    font-size: 28rpx;
    font-weight: 600;
    line-height: 88rpx;
    color: #ffffff;
    background: linear-gradient(135deg, #6366f1 0%, #4338ca 100%);
    border-radius: var(--radius-control);

    &::after {
      border: none;
    }

    &[disabled] {
      color: rgba(255, 255, 255, 0.82);
      background: linear-gradient(135deg, #a5b4fc 0%, #818cf8 100%);
    }
  }
}

.sheet-mask {
  position: fixed;
  z-index: 20;
  top: 0;
  right: 0;
  bottom: 0;
  left: 0;
  display: flex;
  align-items: flex-end;
  background-color: rgba(26, 26, 46, 0.42);
}

.sheet {
  width: 100%;
  max-height: 70vh;
  padding-bottom: env(safe-area-inset-bottom);
  background-color: var(--color-surface);
  border-radius: 32rpx 32rpx 0 0;
  overflow: hidden;

  &__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 28rpx 40rpx;
  }

  &__title {
    font-size: 30rpx;
    font-weight: 600;
    color: var(--color-text);
  }

  &__close {
    font-size: 26rpx;
    color: var(--color-text-tertiary);
  }

  &__body {
    height: 56vh;
  }

  &__item {
    display: flex;
    align-items: center;
    padding: 24rpx 40rpx;

    &:active {
      background-color: var(--color-surface-muted);
    }
  }

  &__icon {
    margin-right: 20rpx;
    font-size: 32rpx;
  }

  &__name {
    flex: 1;
    font-size: 28rpx;
    color: var(--color-text);
  }

  &__check {
    font-size: 28rpx;
    color: var(--color-primary);
  }
}
</style>
