<script setup lang="ts">
import { ref } from 'vue'
import { onPullDownRefresh, onShow } from '@dcloudio/uni-app'

import EmptyState from '@/components/empty-state.vue'
import SummaryCard from '@/components/summary-card.vue'
import TransactionGroup from '@/components/transaction-group.vue'
import {
  deleteTransaction,
  fetchSummary,
  fetchTransactions,
} from '@/api/transaction'
import type {
  MonthlySummary,
  Transaction,
  TransactionGroup as TransactionGroupData,
} from '@/models/types'
import { setPendingEdit } from '@/stores/transaction-edit'
import { showConfirm } from '@/utils/confirm'
import { addMonths } from '@/utils/date'
import { errorMessage } from '@/utils/error'
import { groupTransactions } from '@/utils/group'

const now = new Date()
const year = ref(now.getFullYear())
const month = ref(now.getMonth() + 1)
const summary = ref<MonthlySummary | null>(null)
const groups = ref<TransactionGroupData[]>([])
const loading = ref(true)
const loaded = ref(false)
const error = ref('')

onShow(() => {
  void load()
})

onPullDownRefresh(async () => {
  await load()
  uni.stopPullDownRefresh()
})

async function load(): Promise<void> {
  if (!loaded.value) {
    loading.value = true
  }
  error.value = ''
  try {
    const [nextSummary, rows] = await Promise.all([
      fetchSummary(year.value, month.value),
      fetchTransactions({ year: year.value, month: month.value }),
    ])
    summary.value = nextSummary
    groups.value = groupTransactions(rows)
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

function shiftMonth(delta: number): void {
  const next = addMonths(year.value, month.value, delta)
  year.value = next.year
  month.value = next.month
  loading.value = true
  void load()
}

function openAdd(): void {
  uni.navigateTo({ url: '/pages/add-transaction/index' })
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
  <view class="home">
    <SummaryCard
      :year="year"
      :month="month"
      :income-cents="summary?.incomeCents ?? 0"
      :expense-cents="summary?.expenseCents ?? 0"
      :balance-cents="summary?.totalCents ?? 0"
      @prev="shiftMonth(-1)"
      @next="shiftMonth(1)"
    />

    <view v-if="loading" class="state">
      <text class="state__text">加载中…</text>
    </view>

    <view v-else-if="error" class="state">
      <text class="state__text">{{ error }}</text>
      <view class="state__btn" @tap="load">
        <text class="state__btn-text">重试</text>
      </view>
    </view>

    <template v-else>
      <view v-if="groups.length" class="home__hint">
        <text class="home__hint-text">长按账单可编辑或删除</text>
      </view>
      <EmptyState v-else text="该月还没有记账记录" hint="点右下角按钮记一笔" />

      <TransactionGroup
        v-for="group in groups"
        :key="group.date"
        :group="group"
        @select="handleSelect"
        @remove="handleLongPress"
      />
    </template>

    <view class="home__fab" @tap="openAdd">
      <text class="home__fab-icon">+</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.home {
  min-height: 100vh;
  padding: 24rpx 0 calc(180rpx + env(safe-area-inset-bottom));

  &__hint {
    padding: 20rpx 40rpx 8rpx;
  }

  &__hint-text {
    font-size: 22rpx;
    color: var(--color-text-tertiary);
  }

  &__fab {
    position: fixed;
    right: 40rpx;
    bottom: calc(48rpx + env(safe-area-inset-bottom));
    display: flex;
    align-items: center;
    justify-content: center;
    width: 108rpx;
    height: 108rpx;
    background: linear-gradient(135deg, #6366f1 0%, #4338ca 100%);
    border-radius: 50%;
    box-shadow: 0 16rpx 40rpx rgba(67, 56, 202, 0.35);
  }

  &__fab-icon {
    font-size: 56rpx;
    font-weight: 300;
    line-height: 1;
    color: #ffffff;
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
