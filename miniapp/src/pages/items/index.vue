<script setup lang="ts">
import { computed, ref } from 'vue'
import { onPullDownRefresh, onShow } from '@dcloudio/uni-app'

import EmptyState from '@/components/empty-state.vue'
import { fetchItemSummary, fetchItems } from '@/api/item'
import type { Item, ItemStatus, ItemSummary } from '@/models/types'
import { setPendingItemEdit } from '@/stores/item-edit'
import { parseISODate } from '@/utils/date'
import { errorMessage } from '@/utils/error'
import { formatYuan } from '@/utils/money'

const STATUS_LABELS: Record<ItemStatus, string> = {
  in_use: '在用',
  idle: '闲置',
  sold: '已出售',
  retired: '已报废',
}

const statusOptions: { key: ItemStatus | null; label: string }[] = [
  { key: null, label: '全部' },
  { key: 'in_use', label: '在用' },
  { key: 'idle', label: '闲置' },
  { key: 'sold', label: '已出售' },
  { key: 'retired', label: '已报废' },
]

const items = ref<Item[]>([])
const summary = ref<ItemSummary | null>(null)
const keyword = ref('')
const statusFilter = ref<ItemStatus | null>(null)
const loading = ref(true)
const loaded = ref(false)
const error = ref('')

let searchTimer: ReturnType<typeof setTimeout> | null = null

const hasFilter = computed(
  () => keyword.value.trim().length > 0 || statusFilter.value !== null,
)

interface ItemGroup {
  name: string
  icon: string
  amountCents: number
  items: Item[]
}

const groups = computed<ItemGroup[]>(() => {
  const map = new Map<string, ItemGroup>()
  for (const item of items.value) {
    const key = item.category || '未分类'
    let group = map.get(key)
    if (!group) {
      group = {
        name: key,
        icon: item.categoryIcon || '📦',
        amountCents: 0,
        items: [],
      }
      map.set(key, group)
    }
    group.items.push(item)
    group.amountCents += item.amountCents
  }
  return Array.from(map.values())
})

function load(): Promise<void> {
  loading.value = true
  error.value = ''
  return Promise.all([
    fetchItems({ keyword: keyword.value, status: statusFilter.value }),
    fetchItemSummary(),
  ])
    .then(([nextItems, nextSummary]) => {
      items.value = nextItems
      summary.value = nextSummary
      loaded.value = true
    })
    .catch((err) => {
      error.value = errorMessage(err)
    })
    .finally(() => {
      loading.value = false
    })
}

onShow(() => {
  void load()
})

onPullDownRefresh(() => {
  void load().finally(() => {
    uni.stopPullDownRefresh()
  })
})

function onKeywordInput(event: Event): void {
  const detail = (event as unknown as { detail: { value: string } }).detail
  keyword.value = detail.value
  if (searchTimer) {
    clearTimeout(searchTimer)
  }
  searchTimer = setTimeout(() => {
    void load()
  }, 300)
}

function selectStatus(next: ItemStatus | null): void {
  if (statusFilter.value === next) {
    return
  }
  statusFilter.value = next
  void load()
}

function openCreate(): void {
  setPendingItemEdit(null)
  uni.navigateTo({ url: '/pages/item-edit/index' })
}

function openEdit(item: Item): void {
  setPendingItemEdit(item)
  uni.navigateTo({ url: '/pages/item-edit/index' })
}

function dailyCost(item: Item): number {
  return Math.floor(item.amountCents / Math.max(item.daysUsed, 1))
}

function warrantyLeft(item: Item): number | null {
  if (!item.warrantyUntil) {
    return null
  }
  const until = parseISODate(item.warrantyUntil)
  const now = new Date()
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  return Math.round((until.getTime() - today.getTime()) / 86400000)
}

function warrantyText(item: Item): string {
  const left = warrantyLeft(item)
  if (left === null) {
    return ''
  }
  if (left > 0) {
    return `保修剩 ${left} 天`
  }
  if (left === 0) {
    return '保修今天到期'
  }
  return '已过保'
}

function warrantyClass(item: Item): string {
  const left = warrantyLeft(item)
  return left !== null && left > 0 ? 'item-card__info--good' : ''
}

function profitText(item: Item): string {
  const profit = item.profitCents ?? 0
  const sign = profit >= 0 ? '赚' : '亏'
  return `${sign} ¥${formatYuan(Math.abs(profit))}`
}

function profitClass(item: Item): string {
  const profit = item.profitCents ?? 0
  return profit >= 0 ? 'item-card__info--good' : 'item-card__info--bad'
}

function tintColor(hex: string | null): string {
  if (!hex) {
    return 'rgba(99, 102, 241, 0.12)'
  }
  const value = hex.replace('#', '')
  if (value.length !== 6) {
    return 'rgba(99, 102, 241, 0.12)'
  }
  const r = parseInt(value.slice(0, 2), 16)
  const g = parseInt(value.slice(2, 4), 16)
  const b = parseInt(value.slice(4, 6), 16)
  if ([r, g, b].some((part) => Number.isNaN(part))) {
    return 'rgba(99, 102, 241, 0.12)'
  }
  return `rgba(${r}, ${g}, ${b}, 0.14)`
}
</script>

<template>
  <view class="items">
    <view class="items__head">
      <text class="items__title">物品</text>
    </view>

    <view v-if="summary" class="summary">
      <text class="summary__label">物品总价值</text>
      <text class="summary__value">¥{{ formatYuan(summary.totalAmountCents) }}</text>
      <view class="summary__divider" />
      <view class="summary__grid">
        <view class="summary__stat">
          <text class="summary__stat-label">物品件数</text>
          <text class="summary__stat-value">{{ summary.count }} 件</text>
        </view>
        <view class="summary__stat">
          <text class="summary__stat-label">在用</text>
          <text class="summary__stat-value">{{ summary.inUseCount }} 件</text>
        </view>
        <view class="summary__stat">
          <text class="summary__stat-label">日均成本</text>
          <text class="summary__stat-value">¥{{ formatYuan(summary.dailyCostCents) }}</text>
        </view>
        <view class="summary__stat">
          <text class="summary__stat-label">已实现盈亏</text>
          <text
            class="summary__stat-value"
            :class="
              summary.totalProfitCents >= 0
                ? 'summary__stat-value--good'
                : 'summary__stat-value--bad'
            "
          >
            {{ summary.totalProfitCents >= 0 ? '+' : '-' }}¥{{
              formatYuan(Math.abs(summary.totalProfitCents))
            }}
          </text>
        </view>
      </view>
    </view>

    <view class="search">
      <text class="search__icon">🔍</text>
      <input
        class="search__input"
        type="text"
        :value="keyword"
        placeholder="搜索物品名称、用途或备注"
        placeholder-style="color: #8b8ba3"
        confirm-type="search"
        @input="onKeywordInput"
      />
    </view>

    <scroll-view scroll-x class="chips">
      <view class="chips__inner">
        <view
          v-for="option in statusOptions"
          :key="option.label"
          class="chips__item"
          :class="{
            'chips__item--active': statusFilter === option.key,
          }"
          @tap="selectStatus(option.key)"
        >
          <text
            class="chips__text"
            :class="{
              'chips__text--active': statusFilter === option.key,
            }"
          >
            {{ option.label }}
          </text>
        </view>
      </view>
    </scroll-view>

    <view v-if="loading && !loaded" class="state">
      <text class="state__text">加载中…</text>
    </view>

    <view v-else-if="error" class="state">
      <text class="state__text">{{ error }}</text>
      <view class="state__btn" @tap="load">
        <text class="state__btn-text">重试</text>
      </view>
    </view>

    <EmptyState
      v-else-if="!items.length"
      :text="hasFilter ? '没有符合条件的物品' : '还没有物品档案'"
      :hint="hasFilter ? '' : '点右下角 + 记录第一件大件消费'"
    />

    <view v-else class="groups">
      <view v-for="group in groups" :key="group.name" class="group">
        <view class="group__head">
          <text class="group__icon">{{ group.icon }}</text>
          <text class="group__name">{{ group.name }}</text>
          <text class="group__meta">
            {{ group.items.length }} 件 · ¥{{ formatYuan(group.amountCents) }}
          </text>
        </view>

        <view
          v-for="item in group.items"
          :key="item.id"
          class="item-card"
          @tap="openEdit(item)"
        >
          <view class="item-card__main">
            <view
              class="item-card__icon"
              :style="{ backgroundColor: tintColor(item.categoryColor) }"
            >
              <text class="item-card__emoji">{{ item.categoryIcon || '📦' }}</text>
            </view>
            <view class="item-card__body">
              <text class="item-card__name">{{ item.name }}</text>
              <text class="item-card__sub">
                {{ item.purpose || item.category }}
              </text>
            </view>
            <view class="item-card__right">
              <text class="item-card__amount">
                ¥{{ formatYuan(item.amountCents) }}
              </text>
              <view
                class="item-card__badge"
                :class="`item-card__badge--${item.status}`"
              >
                <text class="item-card__badge-text">
                  {{ STATUS_LABELS[item.status] }}
                </text>
              </view>
            </view>
          </view>

          <view class="item-card__meta">
            <text class="item-card__info">
              购买 {{ item.purchaseDate }}
            </text>
            <text
              v-if="item.status === 'sold' && item.soldDate"
              class="item-card__info"
            >
              出售 {{ item.soldDate }}
            </text>
            <text
              v-if="item.status === 'sold' && item.heldDays !== null"
              class="item-card__info"
            >
              持有 {{ item.heldDays }} 天
            </text>
            <text v-else class="item-card__info">
              已使用 {{ item.daysUsed }} 天
            </text>
            <text v-if="item.status !== 'sold'" class="item-card__info">
              日均 ¥{{ formatYuan(dailyCost(item)) }}
            </text>
            <text
              v-if="item.status === 'sold' && item.profitCents !== null"
              class="item-card__info"
              :class="profitClass(item)"
            >
              {{ profitText(item) }}
            </text>
            <text
              v-if="warrantyText(item)"
              class="item-card__info"
              :class="warrantyClass(item)"
            >
              {{ warrantyText(item) }}
            </text>
          </view>
        </view>
      </view>
    </view>

    <view class="items__bottom" />

    <view class="fab" @tap="openCreate">
      <text class="fab__plus">+</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.items {
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

  &__bottom {
    height: calc(160rpx + env(safe-area-inset-bottom));
  }
}

.summary {
  margin: 24rpx 40rpx 0;
  padding: 32rpx 36rpx 28rpx;
  background: linear-gradient(135deg, #6366f1 0%, #4338ca 100%);
  border-radius: var(--radius-card);
  box-shadow: 0 14rpx 36rpx rgba(67, 56, 202, 0.24);

  &__label {
    font-size: 24rpx;
    color: rgba(255, 255, 255, 0.72);
  }

  &__value {
    display: block;
    margin-top: 10rpx;
    font-size: 56rpx;
    font-weight: 700;
    color: #ffffff;
  }

  &__divider {
    height: 1rpx;
    margin: 24rpx 0 22rpx;
    background-color: rgba(255, 255, 255, 0.18);
  }

  &__grid {
    display: flex;
    flex-wrap: wrap;
  }

  &__stat {
    width: 50%;
    padding: 10rpx 0;

    &:nth-child(odd) {
      padding-right: 16rpx;
    }
  }

  &__stat-label {
    display: block;
    font-size: 22rpx;
    color: rgba(255, 255, 255, 0.66);
  }

  &__stat-value {
    display: block;
    margin-top: 6rpx;
    font-size: 30rpx;
    font-weight: 700;
    color: #ffffff;

    &--good {
      color: #86efac;
    }

    &--bad {
      color: #fca5a5;
    }
  }
}

.search {
  display: flex;
  align-items: center;
  margin: 24rpx 40rpx 0;
  padding: 0 24rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-control);

  &__icon {
    margin-right: 12rpx;
    font-size: 26rpx;
  }

  &__input {
    flex: 1;
    height: 84rpx;
    font-size: 28rpx;
    color: var(--color-text);
  }
}

.chips {
  margin-top: 20rpx;
  white-space: nowrap;

  &__inner {
    display: inline-flex;
    padding: 0 40rpx;
  }

  &__item {
    margin-right: 16rpx;
    padding: 14rpx 28rpx;
    background-color: var(--color-surface);
    border-radius: 999rpx;

    &--active {
      background-color: var(--color-primary);
    }
  }

  &__text {
    font-size: 26rpx;
    font-weight: 500;
    color: var(--color-text-secondary);

    &--active {
      color: #ffffff;
      font-weight: 600;
    }
  }
}

.groups {
  margin-top: 28rpx;
  padding: 0 40rpx;
}

.group {
  margin-bottom: 8rpx;

  &__head {
    display: flex;
    align-items: center;
    padding: 8rpx 2rpx 16rpx;
  }

  &__icon {
    margin-right: 10rpx;
    font-size: 26rpx;
  }

  &__name {
    font-size: 26rpx;
    font-weight: 600;
    color: var(--color-text-secondary);
  }

  &__meta {
    margin-left: 12rpx;
    font-size: 22rpx;
    color: var(--color-text-tertiary);
  }
}

.item-card {
  margin-bottom: 20rpx;
  padding: 26rpx 28rpx;
  background-color: var(--color-surface);
  border-radius: 24rpx;
  box-shadow: var(--shadow-card);

  &__main {
    display: flex;
    align-items: flex-start;
  }

  &__icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 84rpx;
    height: 84rpx;
    border-radius: 22rpx;
    flex-shrink: 0;
  }

  &__emoji {
    font-size: 42rpx;
  }

  &__body {
    flex: 1;
    min-width: 0;
    margin-left: 22rpx;
  }

  &__name {
    display: block;
    font-size: 30rpx;
    font-weight: 600;
    color: var(--color-text);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  &__sub {
    display: block;
    margin-top: 8rpx;
    font-size: 24rpx;
    color: var(--color-text-tertiary);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  &__right {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    margin-left: 16rpx;
    flex-shrink: 0;
  }

  &__amount {
    font-size: 30rpx;
    font-weight: 700;
    color: var(--color-text);
  }

  &__badge {
    margin-top: 10rpx;
    padding: 4rpx 14rpx;
    border-radius: 8rpx;

    &--in_use {
      background-color: rgba(22, 163, 74, 0.14);
      color: var(--color-income);
    }

    &--idle {
      background-color: var(--color-surface-muted);
      color: var(--color-text-tertiary);
    }

    &--sold {
      background-color: var(--color-primary-soft);
      color: var(--color-primary-deep);
    }

    &--retired {
      background-color: rgba(220, 38, 38, 0.12);
      color: var(--color-danger);
    }
  }

  &__badge-text {
    font-size: 20rpx;
    font-weight: 600;
  }

  &__meta {
    display: flex;
    flex-wrap: wrap;
    margin-top: 18rpx;
    margin-left: 106rpx;
  }

  &__info {
    margin-right: 20rpx;
    margin-top: 6rpx;
    font-size: 22rpx;
    color: var(--color-text-tertiary);

    &--good {
      color: var(--color-income);
    }

    &--bad {
      color: var(--color-expense);
    }
  }
}

.fab {
  position: fixed;
  right: 40rpx;
  bottom: calc(48rpx + env(safe-area-inset-bottom));
  display: flex;
  align-items: center;
  justify-content: center;
  width: 104rpx;
  height: 104rpx;
  background: linear-gradient(135deg, #6366f1 0%, #4338ca 100%);
  border-radius: 50%;
  box-shadow: 0 16rpx 36rpx rgba(67, 56, 202, 0.32);
  z-index: 10;

  &__plus {
    font-size: 52rpx;
    font-weight: 300;
    line-height: 1;
    color: #ffffff;
  }
}

.state {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 120rpx 40rpx;

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
