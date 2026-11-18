<script setup lang="ts">
import { computed, ref } from 'vue'
import { onPullDownRefresh, onShow } from '@dcloudio/uni-app'

import EmptyState from '@/components/empty-state.vue'
import TransactionGroup from '@/components/transaction-group.vue'
import {
  deleteTransaction,
  fetchCategories,
  fetchTransactions,
} from '@/api/transaction'
import type {
  Category,
  Transaction,
  TransactionType,
} from '@/models/types'
import { setPendingEdit } from '@/stores/transaction-edit'
import { showConfirm } from '@/utils/confirm'
import {
  addDaysISO,
  addMonths,
  rangeLabel,
  startOfWeekISO,
  todayISO,
} from '@/utils/date'
import { errorMessage } from '@/utils/error'
import { groupTransactions } from '@/utils/group'
import { formatYuan } from '@/utils/money'

type Span = 'week' | 'month' | 'year'

const now = new Date()
const span = ref<Span>('month')
const year = ref(now.getFullYear())
const month = ref(now.getMonth() + 1)
const rangeStart = ref('')
const rangeEnd = ref('')
const keyword = ref('')
const typeFilter = ref<TransactionType | null>(null)
const categoryId = ref<number | null>(null)
const categories = ref<Category[]>([])
const transactions = ref<Transaction[]>([])
const loading = ref(true)
const loaded = ref(false)
const error = ref('')

let searchTimer: ReturnType<typeof setTimeout> | null = null

const spanOptions: { key: Span; label: string }[] = [
  { key: 'week', label: '周' },
  { key: 'month', label: '月' },
  { key: 'year', label: '年' },
]

const groups = computed(() => groupTransactions(transactions.value))

const totals = computed(() => {
  let income = 0
  let expense = 0
  for (const transaction of transactions.value) {
    if (transaction.type === 'income') {
      income += transaction.amountCents
    } else {
      expense += transaction.amountCents
    }
  }
  return { income, expense, balance: income - expense }
})

const hasFilter = computed(
  () =>
    keyword.value.trim().length > 0 ||
    typeFilter.value !== null ||
    categoryId.value !== null,
)

const periodLabel = computed(() => {
  if (span.value === 'week') {
    return rangeLabel(rangeStart.value, rangeEnd.value)
  }
  if (span.value === 'year') {
    return `${year.value}年`
  }
  return `${year.value}年${month.value}月`
})

const emptyText = computed(() => {
  if (hasFilter.value) {
    return '没有符合条件的账单'
  }
  if (span.value === 'week') {
    return '该周暂无账单'
  }
  if (span.value === 'year') {
    return '该年暂无账单'
  }
  return '该月暂无账单'
})

const selectableCategories = computed(() =>
  categories.value.filter(
    (category) => typeFilter.value === null || category.type === typeFilter.value,
  ),
)

const categoryLabels = computed(() => [
  '全部分类',
  ...selectableCategories.value.map(
    (category) => `${category.icon} ${category.name}`,
  ),
])

const categoryIndex = computed(() => {
  if (categoryId.value === null) {
    return 0
  }
  const index = selectableCategories.value.findIndex(
    (category) => category.id === categoryId.value,
  )
  return index >= 0 ? index + 1 : 0
})

const categoryLabel = computed(() => {
  if (categoryId.value === null) {
    return '全部分类'
  }
  const category = categories.value.find(
    (item) => item.id === categoryId.value,
  )
  return category ? `${category.icon} ${category.name}` : '全部分类'
})

onShow(() => {
  if (!categories.value.length) {
    void loadCategories()
  }
  void load()
})

onPullDownRefresh(async () => {
  await load()
  uni.stopPullDownRefresh()
})

async function loadCategories(): Promise<void> {
  try {
    categories.value = await fetchCategories()
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  }
}

async function load(): Promise<void> {
  if (!loaded.value) {
    loading.value = true
  }
  error.value = ''
  try {
    const rows = await fetchTransactions({
      year: year.value,
      month: month.value,
      keyword: keyword.value.trim() || undefined,
      categoryId: categoryId.value ?? undefined,
      type: typeFilter.value ?? undefined,
      start: span.value === 'month' ? undefined : rangeStart.value,
      end: span.value === 'month' ? undefined : rangeEnd.value,
    })
    transactions.value = rows
    loaded.value = true
  } catch (err) {
    if (loaded.value) {
      uni.showToast({ title: errorMessage(err), icon: 'none' })
    } else {
      error.value = errorMessage(err)
    }
  } finally {
    loading.value = false
  }
}

function monthStartISO(): string {
  return `${year.value}-${String(month.value).padStart(2, '0')}-01`
}

function isCurrentMonth(): boolean {
  const current = new Date()
  return (
    year.value === current.getFullYear() &&
    month.value === current.getMonth() + 1
  )
}

function switchSpan(next: Span): void {
  if (span.value === next) {
    return
  }
  span.value = next
  if (next === 'week') {
    const anchor = isCurrentMonth() ? todayISO() : monthStartISO()
    rangeStart.value = startOfWeekISO(anchor)
    rangeEnd.value = addDaysISO(rangeStart.value, 6)
  } else if (next === 'year') {
    rangeStart.value = `${year.value}-01-01`
    rangeEnd.value = `${year.value}-12-31`
  }
  loading.value = true
  void load()
}

function changePeriod(delta: number): void {
  if (span.value === 'week') {
    rangeStart.value = addDaysISO(rangeStart.value, delta * 7)
    rangeEnd.value = addDaysISO(rangeStart.value, 6)
  } else if (span.value === 'year') {
    year.value += delta
    rangeStart.value = `${year.value}-01-01`
    rangeEnd.value = `${year.value}-12-31`
  } else {
    const next = addMonths(year.value, month.value, delta)
    year.value = next.year
    month.value = next.month
  }
  loading.value = true
  void load()
}

function onKeywordInput(event: Event): void {
  const detail = (event as unknown as { detail: { value: string } }).detail
  keyword.value = detail.value
  if (searchTimer) {
    clearTimeout(searchTimer)
  }
  searchTimer = setTimeout(() => {
    loading.value = true
    void load()
  }, 300)
}

function selectType(next: TransactionType | null): void {
  typeFilter.value = next
  if (
    categoryId.value !== null &&
    !categories.value.some(
      (category) =>
        category.id === categoryId.value &&
        (next === null || category.type === next),
    )
  ) {
    categoryId.value = null
  }
  loading.value = true
  void load()
}

function onCategoryChange(event: { detail: { value: number | string } }): void {
  const index = Number(event.detail.value)
  if (index <= 0) {
    categoryId.value = null
  } else {
    categoryId.value = selectableCategories.value[index - 1]?.id ?? null
  }
  loading.value = true
  void load()
}

let longPressAt = 0

function openEdit(transaction: Transaction): void {
  setPendingEdit(transaction)
  uni.navigateTo({ url: '/pages/add-transaction/index' })
}

function handleSelect(transaction: Transaction): void {
  if (Date.now() - longPressAt < 600) {
    return
  }
  openEdit(transaction)
}

function handleLongPress(transaction: Transaction): void {
  longPressAt = Date.now()
  uni.showActionSheet({
    itemList: ['编辑', '删除'],
    success: (result) => {
      if (result.tapIndex === 0) {
        openEdit(transaction)
      } else if (result.tapIndex === 1) {
        void handleDelete(transaction)
      }
    },
  })
}

async function handleDelete(transaction: Transaction): Promise<void> {
  const confirmed = await showConfirm(
    '删除账单',
    `确定删除「${transaction.title}」吗？删除后不可恢复。`,
    '删除',
  )
  if (!confirmed) {
    return
  }
  try {
    await deleteTransaction(transaction.id)
    uni.showToast({ title: '已删除', icon: 'none' })
    await load()
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  }
}
</script>

<template>
  <view class="bills">
    <view class="bills__head">
      <text class="bills__title">账单</text>
    </view>

    <view class="slider">
      <view
        v-for="item in spanOptions"
        :key="item.key"
        class="slider__item"
        :class="{ 'slider__item--active': span === item.key }"
        @tap="switchSpan(item.key)"
      >
        <text
          class="slider__text"
          :class="{ 'slider__text--active': span === item.key }"
        >
          {{ item.label }}
        </text>
      </view>
    </view>

    <view class="period">
      <view class="period__nav" @tap="changePeriod(-1)">
        <text class="period__arrow">‹</text>
      </view>
      <text class="period__label">{{ periodLabel }}</text>
      <view class="period__nav" @tap="changePeriod(1)">
        <text class="period__arrow">›</text>
      </view>
    </view>

    <view class="search">
      <text class="search__icon">🔍</text>
      <input
        class="search__input"
        type="text"
        :value="keyword"
        placeholder="搜索标题、分类或标签"
        placeholder-style="color: #8b8ba3"
        confirm-type="search"
        @input="onKeywordInput"
      />
    </view>

    <view class="segments">
      <view
        class="segments__item"
        :class="{ 'segments__item--active': typeFilter === null }"
        @tap="selectType(null)"
      >
        <text
          class="segments__text"
          :class="{ 'segments__text--active': typeFilter === null }"
        >
          全部
        </text>
      </view>
      <view
        class="segments__item"
        :class="{ 'segments__item--active': typeFilter === 'expense' }"
        @tap="selectType('expense')"
      >
        <text
          class="segments__text"
          :class="{ 'segments__text--active': typeFilter === 'expense' }"
        >
          支出
        </text>
      </view>
      <view
        class="segments__item"
        :class="{ 'segments__item--active': typeFilter === 'income' }"
        @tap="selectType('income')"
      >
        <text
          class="segments__text"
          :class="{ 'segments__text--active': typeFilter === 'income' }"
        >
          收入
        </text>
      </view>
    </view>

    <picker
      mode="selector"
      :range="categoryLabels"
      :value="categoryIndex"
      @change="onCategoryChange"
    >
      <view class="category">
        <text class="category__label">{{ categoryLabel }}</text>
        <text class="category__arrow">▾</text>
      </view>
    </picker>

    <view v-if="loading && !loaded" class="state">
      <text class="state__text">加载中…</text>
    </view>

    <view v-else-if="error && !loaded" class="state">
      <text class="state__text">{{ error }}</text>
      <view class="state__btn" @tap="load">
        <text class="state__btn-text">重试</text>
      </view>
    </view>

    <template v-else>
      <view v-if="transactions.length" class="stats">
        <view class="stats__item">
          <text class="stats__label">收入</text>
          <text class="stats__value stats__value--income">
            +¥{{ formatYuan(totals.income) }}
          </text>
        </view>
        <view class="stats__divider" />
        <view class="stats__item">
          <text class="stats__label">支出</text>
          <text class="stats__value stats__value--expense">
            -¥{{ formatYuan(totals.expense) }}
          </text>
        </view>
        <view class="stats__divider" />
        <view class="stats__item">
          <text class="stats__label">结余</text>
          <text class="stats__value">
            ¥{{ formatYuan(totals.balance) }}
          </text>
        </view>
      </view>

      <view v-if="transactions.length" class="bills__hint">
        <text class="bills__hint-text">长按账单可编辑或删除</text>
      </view>
      <EmptyState
        v-else
        :text="emptyText"
        :hint="hasFilter ? '试试调整筛选条件' : undefined"
      />

      <TransactionGroup
        v-for="group in groups"
        :key="group.date"
        :group="group"
        @select="handleSelect"
        @remove="handleLongPress"
      />
    </template>

    <view class="bills__bottom" />
  </view>
</template>

<style lang="scss" scoped>
.bills {
  min-height: 100vh;
  padding-top: 24rpx;

  &__head {
    padding: 0 40rpx;
  }

  &__title {
    font-size: 44rpx;
    font-weight: 700;
    color: var(--color-text);
  }

  &__hint {
    padding: 8rpx 40rpx 16rpx;
  }

  &__hint-text {
    font-size: 22rpx;
    color: var(--color-text-tertiary);
  }

  &__bottom {
    height: calc(48rpx + env(safe-area-inset-bottom));
  }
}

.slider {
  display: flex;
  margin: 24rpx 40rpx 8rpx;
  padding: 6rpx;
  background-color: var(--color-surface);
  border-radius: 20rpx;

  &__item {
    display: flex;
    flex: 1;
    align-items: center;
    justify-content: center;
    padding: 14rpx 0;
    border-radius: 16rpx;

    &--active {
      background-color: var(--color-primary);
    }
  }

  &__text {
    font-size: 28rpx;
    font-weight: 600;
    color: var(--color-text-secondary);

    &--active {
      color: #ffffff;
    }
  }
}

.period {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 8rpx 40rpx 16rpx;

  &__nav {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 56rpx;
    height: 56rpx;
  }

  &__arrow {
    font-size: 40rpx;
    line-height: 1;
    color: var(--color-text-secondary);
  }

  &__label {
    min-width: 320rpx;
    font-size: 32rpx;
    font-weight: 600;
    color: var(--color-text);
    text-align: center;
  }
}

.search {
  display: flex;
  align-items: center;
  margin: 0 40rpx;
  padding: 0 24rpx;
  background-color: var(--color-surface);
  border-radius: 20rpx;

  &__icon {
    margin-right: 12rpx;
    font-size: 26rpx;
  }

  &__input {
    flex: 1;
    height: 80rpx;
    font-size: 28rpx;
    color: var(--color-text);
  }
}

.segments {
  display: flex;
  margin: 20rpx 40rpx 0;
  padding: 6rpx;
  background-color: var(--color-surface);
  border-radius: 20rpx;

  &__item {
    display: flex;
    flex: 1;
    align-items: center;
    justify-content: center;
    padding: 12rpx 0;
    border-radius: 16rpx;

    &--active {
      background-color: var(--color-primary-soft);
    }
  }

  &__text {
    font-size: 26rpx;
    font-weight: 500;
    color: var(--color-text-secondary);

    &--active {
      font-weight: 600;
      color: var(--color-primary-deep);
    }
  }
}

.category {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin: 16rpx 40rpx 0;
  padding: 22rpx 28rpx;
  background-color: var(--color-surface);
  border-radius: 20rpx;

  &__label {
    font-size: 28rpx;
    color: var(--color-text);
  }

  &__arrow {
    font-size: 24rpx;
    color: var(--color-text-tertiary);
  }
}

.stats {
  display: flex;
  align-items: center;
  margin: 24rpx 40rpx 8rpx;
  padding: 24rpx 0;
  background-color: var(--color-surface);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);

  &__item {
    display: flex;
    flex: 1;
    flex-direction: column;
    align-items: center;
  }

  &__divider {
    width: 1rpx;
    height: 56rpx;
    background-color: var(--color-border);
  }

  &__label {
    font-size: 22rpx;
    color: var(--color-text-secondary);
  }

  &__value {
    margin-top: 8rpx;
    font-size: 28rpx;
    font-weight: 700;
    color: var(--color-text);

    &--income {
      color: var(--color-income);
    }

    &--expense {
      color: var(--color-expense);
    }
  }
}

.state {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 96rpx 40rpx;

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
