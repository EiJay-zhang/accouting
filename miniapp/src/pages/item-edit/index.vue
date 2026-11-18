<script setup lang="ts">
import { computed, ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'

import { createItem, deleteItem, updateItem } from '@/api/item'
import type { ItemPayload } from '@/api/item'
import { fetchCategories } from '@/api/transaction'
import type { Category, Item, ItemStatus } from '@/models/types'
import { takePendingItemEdit } from '@/stores/item-edit'
import { showConfirm } from '@/utils/confirm'
import { parseISODate, todayISO } from '@/utils/date'
import { errorMessage } from '@/utils/error'
import { centsFromYuan, formatYuan, formatYuanInput } from '@/utils/money'

const editing = ref<Item | null>(null)
const amountText = ref('')
const name = ref('')
const purchaseDate = ref(todayISO())
const categoryId = ref<number | null>(null)
const purpose = ref('')
const status = ref<ItemStatus>('in_use')
const soldAmountText = ref('')
const soldDate = ref<string | null>(null)
const warrantyUntil = ref<string | null>(null)
const note = ref('')
const categories = ref<Category[]>([])
const loading = ref(true)
const loadError = ref('')
const submitting = ref(false)

const statusOptions: { key: ItemStatus; label: string }[] = [
  { key: 'in_use', label: '在用' },
  { key: 'idle', label: '闲置' },
  { key: 'sold', label: '已出售' },
  { key: 'retired', label: '已报废' },
]

const amountCents = computed(() => {
  const value = Number(amountText.value.trim())
  if (!amountText.value.trim() || !Number.isFinite(value) || value <= 0) {
    return null
  }
  return centsFromYuan(value)
})

const daysUsed = computed(() => {
  const now = new Date()
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const start = parseISODate(purchaseDate.value)
  const days = Math.round((today.getTime() - start.getTime()) / 86400000)
  return days < 0 ? 0 : days
})

const previewText = computed(() => {
  const cents = amountCents.value
  if (cents === null) {
    return ''
  }
  const days = daysUsed.value
  const perDay = Math.floor(cents / (days < 1 ? 1 : days))
  return `已使用 ${days} 天，日均成本 ¥${formatYuan(perDay)}`
})

const purchaseDateLabel = computed(() => dateLabel(purchaseDate.value))
const soldDateLabel = computed(() =>
  soldDate.value ? dateLabel(soldDate.value) : '请选择日期',
)
const warrantyLabel = computed(() =>
  warrantyUntil.value ? dateLabel(warrantyUntil.value) : '未设置',
)

onLoad(() => {
  const existing = takePendingItemEdit()
  if (existing) {
    editing.value = existing
    amountText.value = formatYuanInput(existing.amountCents)
    name.value = existing.name
    purchaseDate.value = existing.purchaseDate.slice(0, 10)
    categoryId.value = existing.categoryId
    purpose.value = existing.purpose
    status.value = existing.status
    soldAmountText.value =
      existing.soldAmountCents === null
        ? ''
        : formatYuanInput(existing.soldAmountCents)
    soldDate.value = existing.soldDate ? existing.soldDate.slice(0, 10) : null
    warrantyUntil.value = existing.warrantyUntil
      ? existing.warrantyUntil.slice(0, 10)
      : null
    note.value = existing.note
    uni.setNavigationBarTitle({ title: '编辑物品' })
  } else {
    uni.setNavigationBarTitle({ title: '新增物品' })
  }
  void loadCategories()
})

async function loadCategories(): Promise<void> {
  loading.value = true
  loadError.value = ''
  try {
    const rows = await fetchCategories('expense')
    categories.value = rows
    if (
      categoryId.value === null ||
      !rows.some((row) => row.id === categoryId.value)
    ) {
      categoryId.value = rows[0]?.id ?? null
    }
  } catch (err) {
    loadError.value = errorMessage(err)
  } finally {
    loading.value = false
  }
}

function dateLabel(iso: string): string {
  const value = parseISODate(iso)
  return `${value.getFullYear()}年${value.getMonth() + 1}月${value.getDate()}日`
}

function onAmountInput(event: Event): void {
  const detail = (event as unknown as { detail: { value: string } }).detail
  amountText.value = detail.value
}

function onNameInput(event: Event): void {
  const detail = (event as unknown as { detail: { value: string } }).detail
  name.value = detail.value
}

function onPurposeInput(event: Event): void {
  const detail = (event as unknown as { detail: { value: string } }).detail
  purpose.value = detail.value
}

function onNoteInput(event: Event): void {
  const detail = (event as unknown as { detail: { value: string } }).detail
  note.value = detail.value
}

function onSoldAmountInput(event: Event): void {
  const detail = (event as unknown as { detail: { value: string } }).detail
  soldAmountText.value = detail.value
}

function onPurchaseDateChange(event: { detail: { value: string } }): void {
  purchaseDate.value = event.detail.value
}

function onSoldDateChange(event: { detail: { value: string } }): void {
  soldDate.value = event.detail.value
}

function onWarrantyChange(event: { detail: { value: string } }): void {
  warrantyUntil.value = event.detail.value
}

function selectCategory(id: number): void {
  if (submitting.value) {
    return
  }
  categoryId.value = id
}

function confirmSold(): Promise<boolean> {
  return new Promise((resolve) => {
    uni.showModal({
      title: '确认标记为「已出售」？',
      content:
        '保存后将自动生成一条收入账单（出售金额），该物品也会从物品总价值中排除。',
      confirmText: '确认',
      cancelText: '取消',
      success: (result) => resolve(result.confirm),
      fail: () => resolve(false),
    })
  })
}

async function selectStatus(next: ItemStatus): Promise<void> {
  if (next === status.value || submitting.value) {
    return
  }
  if (next === 'sold') {
    const confirmed = await confirmSold()
    if (!confirmed) {
      return
    }
  }
  status.value = next
  if (next !== 'sold') {
    soldAmountText.value = ''
    soldDate.value = null
  }
}

function toast(message: string): void {
  uni.showToast({ title: message, icon: 'none' })
}

function buildPayload(): ItemPayload | null {
  const label = name.value.trim()
  if (!label) {
    toast('请填写物品名称')
    return null
  }
  const cents = amountCents.value
  if (cents === null) {
    toast('请填写有效的购买金额')
    return null
  }
  if (categoryId.value === null) {
    toast('请选择物品分类')
    return null
  }

  let soldAmount: number | null = null
  if (status.value === 'sold') {
    const raw = soldAmountText.value.trim()
    if (!raw) {
      toast('请填写出售金额')
      return null
    }
    const value = Number(raw)
    if (!Number.isFinite(value) || value < 0) {
      toast('请填写有效的出售金额')
      return null
    }
    soldAmount = centsFromYuan(value) / 100
  }

  return {
    name: label,
    category_id: categoryId.value,
    amount: cents / 100,
    purchase_date: purchaseDate.value,
    purpose: purpose.value.trim(),
    status: status.value,
    sold_amount: soldAmount,
    sold_date: status.value === 'sold' ? soldDate.value || todayISO() : null,
    warranty_until: warrantyUntil.value || null,
    note: note.value.trim(),
  }
}

async function submit(): Promise<void> {
  if (submitting.value) {
    return
  }
  const payload = buildPayload()
  if (!payload) {
    return
  }

  submitting.value = true
  try {
    if (editing.value) {
      await updateItem(editing.value.id, payload)
    } else {
      await createItem(payload)
    }
    uni.showToast({ title: '已保存', icon: 'success', duration: 600 })
    setTimeout(() => {
      uni.navigateBack()
    }, 600)
  } catch (err) {
    toast(errorMessage(err))
  } finally {
    submitting.value = false
  }
}

async function handleDelete(): Promise<void> {
  const target = editing.value
  if (!target || submitting.value) {
    return
  }
  const confirmed = await showConfirm(
    '删除物品',
    `确定删除「${target.name}」的档案吗？`,
    '删除',
  )
  if (!confirmed) {
    return
  }

  submitting.value = true
  try {
    await deleteItem(target.id)
    uni.showToast({ title: '已删除', icon: 'none' })
    setTimeout(() => {
      uni.navigateBack()
    }, 400)
  } catch (err) {
    toast(errorMessage(err))
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <view class="page">
    <view v-if="loading" class="state">
      <text class="state__text">加载中…</text>
    </view>

    <view v-else-if="loadError" class="state">
      <text class="state__text">{{ loadError }}</text>
      <view class="state__btn" @tap="loadCategories">
        <text class="state__btn-text">重试</text>
      </view>
    </view>

    <template v-else>
      <view class="amount-card">
        <text class="amount-card__label">购入金额</text>
        <view class="amount-card__row">
          <text class="amount-card__symbol">¥</text>
          <input
            class="amount-card__input"
            type="digit"
            :value="amountText"
            :disabled="submitting"
            placeholder="0.00"
            placeholder-style="color: #8b8ba3"
            @input="onAmountInput"
          />
        </view>
        <text v-if="previewText" class="amount-card__preview">
          {{ previewText }}
        </text>
      </view>

      <view class="block">
        <text class="block__title">物品名称</text>
        <view class="field">
          <input
            class="field__input"
            type="text"
            :value="name"
            :disabled="submitting"
            maxlength="60"
            placeholder="例如 笔记本电脑、电动车"
            placeholder-style="color: #8b8ba3"
            @input="onNameInput"
          />
        </view>
      </view>

      <view class="block">
        <text class="block__title">购买日期</text>
        <picker
          mode="date"
          :value="purchaseDate"
          start="2000-01-01"
          :end="todayISO()"
          @change="onPurchaseDateChange"
        >
          <view class="field field--row">
            <text class="field__icon">📅</text>
            <text class="field__value">{{ purchaseDateLabel }}</text>
            <text class="field__arrow">›</text>
          </view>
        </picker>
      </view>

      <view class="block">
        <text class="block__title">物品分类</text>
        <view v-if="categories.length" class="choices">
          <view
            v-for="category in categories"
            :key="category.id"
            class="choice"
            :style="
              categoryId === category.id
                ? { backgroundColor: category.color }
                : {}
            "
            @tap="selectCategory(category.id)"
          >
            <text class="choice__icon">{{ category.icon }}</text>
            <text
              class="choice__label"
              :class="{
                'choice__label--active': categoryId === category.id,
              }"
            >
              {{ category.name }}
            </text>
          </view>
        </view>
        <view v-else class="hint">
          <text class="hint__text">
            还没有支出分类，请先到「我的 - 分类管理」里添加
          </text>
        </view>
      </view>

      <view class="block">
        <text class="block__title">当前状态</text>
        <view class="choices">
          <view
            v-for="option in statusOptions"
            :key="option.key"
            class="choice choice--status"
            :class="{
              'choice--status-active': status === option.key,
            }"
            @tap="selectStatus(option.key)"
          >
            <text
              class="choice__label"
              :class="{
                'choice__label--active': status === option.key,
              }"
            >
              {{ option.label }}
            </text>
          </view>
        </view>
        <text v-if="status === 'sold'" class="block__hint">
          保存后会自动生成一条收入账单；改回其他状态会自动删除该账单。
        </text>
      </view>

      <template v-if="status === 'sold'">
        <view class="block">
          <text class="block__title">出售金额</text>
          <view class="field field--amount">
            <text class="field__symbol">¥</text>
            <input
              class="field__input"
              type="digit"
              :value="soldAmountText"
              :disabled="submitting"
              placeholder="0.00"
              placeholder-style="color: #8b8ba3"
              @input="onSoldAmountInput"
            />
          </view>
        </view>

        <view class="block">
          <text class="block__title">出售日期</text>
          <picker
            mode="date"
            :value="soldDate || todayISO()"
            :start="purchaseDate"
            :end="todayISO()"
            @change="onSoldDateChange"
          >
            <view class="field field--row">
              <text class="field__icon">📅</text>
              <text
                class="field__value"
                :class="{ 'field__value--muted': !soldDate }"
              >
                {{ soldDateLabel }}
              </text>
              <text class="field__arrow">›</text>
            </view>
          </picker>
        </view>
      </template>

      <view class="block">
        <text class="block__title">保修到期日（选填）</text>
        <picker
          mode="date"
          :value="warrantyUntil || purchaseDate"
          start="2000-01-01"
          end="2036-12-31"
          @change="onWarrantyChange"
        >
          <view class="field field--row">
            <text class="field__icon">🛡️</text>
            <text
              class="field__value"
              :class="{ 'field__value--muted': !warrantyUntil }"
            >
              {{ warrantyLabel }}
            </text>
            <view
              v-if="warrantyUntil"
              class="field__clear"
              @tap.stop="warrantyUntil = null"
            >
              <text class="field__clear-text">×</text>
            </view>
            <text class="field__arrow">›</text>
          </view>
        </picker>
      </view>

      <view class="block">
        <text class="block__title">用途</text>
        <view class="field field--textarea">
          <textarea
            class="field__textarea"
            :value="purpose"
            :disabled="submitting"
            maxlength="200"
            placeholder="例如 通勤代步、主力办公"
            placeholder-style="color: #8b8ba3"
            @input="onPurposeInput"
          />
        </view>
      </view>

      <view class="block">
        <text class="block__title">备注</text>
        <view class="field field--textarea">
          <textarea
            class="field__textarea"
            :value="note"
            :disabled="submitting"
            maxlength="500"
            placeholder="维修记录、使用心得等"
            placeholder-style="color: #8b8ba3"
            @input="onNoteInput"
          />
        </view>
      </view>

      <view class="save" @tap="submit">
        <text class="save__text">
          {{ submitting ? '保存中…' : editing ? '保存修改' : '保存档案' }}
        </text>
      </view>

      <view v-if="editing" class="delete" @tap="handleDelete">
        <text class="delete__text">删除物品</text>
      </view>
    </template>
  </view>
</template>

<style lang="scss" scoped>
.page {
  min-height: 100vh;
  padding: 32rpx 40rpx calc(64rpx + env(safe-area-inset-bottom));
}

.amount-card {
  padding: 30rpx 32rpx 24rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);

  &__label {
    font-size: 24rpx;
    color: var(--color-text-tertiary);
  }

  &__row {
    display: flex;
    align-items: flex-end;
    margin-top: 8rpx;
  }

  &__symbol {
    margin-right: 10rpx;
    font-size: 44rpx;
    font-weight: 600;
    color: var(--color-text);
    line-height: 1.3;
  }

  &__input {
    flex: 1;
    height: 88rpx;
    font-size: 64rpx;
    font-weight: 700;
    color: var(--color-text);
  }

  &__preview {
    display: block;
    margin-top: 8rpx;
    font-size: 22rpx;
    color: var(--color-text-tertiary);
  }
}

.block {
  margin-top: 32rpx;

  &__title {
    display: block;
    margin-bottom: 16rpx;
    font-size: 26rpx;
    font-weight: 500;
    color: var(--color-text-secondary);
  }

  &__hint {
    display: block;
    margin-top: 16rpx;
    font-size: 22rpx;
    color: var(--color-text-tertiary);
    line-height: 1.5;
  }
}

.field {
  display: flex;
  align-items: center;
  padding: 0 28rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-control);

  &--row {
    padding-top: 26rpx;
    padding-bottom: 26rpx;
  }

  &--amount {
    padding-top: 20rpx;
    padding-bottom: 20rpx;
  }

  &--textarea {
    padding-top: 20rpx;
    padding-bottom: 20rpx;
  }

  &__input {
    flex: 1;
    height: 88rpx;
    font-size: 30rpx;
    color: var(--color-text);
  }

  &__icon {
    margin-right: 16rpx;
    font-size: 28rpx;
  }

  &__value {
    flex: 1;
    font-size: 30rpx;
    color: var(--color-text);

    &--muted {
      color: var(--color-text-tertiary);
    }
  }

  &__symbol {
    margin-right: 10rpx;
    font-size: 34rpx;
    font-weight: 600;
    color: var(--color-text);
  }

  &__clear {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 40rpx;
    height: 40rpx;
    margin-right: 12rpx;
    background-color: var(--color-surface-muted);
    border-radius: 50%;
  }

  &__clear-text {
    font-size: 26rpx;
    color: var(--color-text-tertiary);
    line-height: 1;
  }

  &__textarea {
    width: 100%;
    height: 140rpx;
    font-size: 28rpx;
    color: var(--color-text);
    line-height: 1.6;
  }

  &__arrow {
    font-size: 32rpx;
    color: var(--color-text-tertiary);
  }
}

.choices {
  display: flex;
  flex-wrap: wrap;
}

.choice {
  display: flex;
  align-items: center;
  margin-right: 16rpx;
  margin-bottom: 16rpx;
  padding: 14rpx 24rpx;
  background-color: var(--color-surface);
  border-radius: 16rpx;

  &--status {
    padding: 16rpx 32rpx;
  }

  &--status-active {
    background-color: var(--color-primary);
  }

  &__icon {
    margin-right: 8rpx;
    font-size: 28rpx;
  }

  &__label {
    font-size: 26rpx;
    font-weight: 500;
    color: var(--color-text-secondary);

    &--active {
      color: #ffffff;
      font-weight: 600;
    }
  }
}

.hint {
  padding: 24rpx 28rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-control);

  &__text {
    font-size: 24rpx;
    color: var(--color-text-tertiary);
  }
}

.save {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100rpx;
  margin-top: 48rpx;
  background: linear-gradient(135deg, #6366f1 0%, #4338ca 100%);
  border-radius: var(--radius-control);
  box-shadow: 0 14rpx 32rpx rgba(67, 56, 202, 0.24);

  &__text {
    font-size: 30rpx;
    font-weight: 600;
    color: #ffffff;
  }
}

.delete {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 88rpx;
  margin-top: 24rpx;
  background-color: var(--color-surface);
  border: 2rpx solid var(--color-border);
  border-radius: var(--radius-control);

  &__text {
    font-size: 28rpx;
    color: var(--color-danger);
  }
}

.state {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 160rpx 40rpx;

  &__text {
    font-size: 28rpx;
    color: var(--color-text-secondary);
    text-align: center;
  }

  &__btn {
    margin-top: 32rpx;
    padding: 16rpx 56rpx;
    background-color: var(--color-primary);
    border-radius: 999rpx;
  }

  &__btn-text {
    font-size: 28rpx;
    font-weight: 600;
    color: #ffffff;
  }
}
</style>
