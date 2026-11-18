<script setup lang="ts">
import { computed } from 'vue'

import type { Transaction, TransactionGroup } from '@/models/types'
import { dayLabel, weekdayLabel } from '@/utils/date'
import { formatSignedYuan } from '@/utils/money'
import TransactionItem from '@/components/transaction-item.vue'

const props = defineProps<{
  group: TransactionGroup
}>()

const emit = defineEmits<{
  (event: 'select', transaction: Transaction): void
  (event: 'remove', transaction: Transaction): void
}>()

const netCents = computed(() =>
  props.group.transactions.reduce(
    (total, transaction) =>
      total +
      (transaction.type === 'income'
        ? transaction.amountCents
        : -transaction.amountCents),
    0,
  ),
)

const netClass = computed(() => {
  if (netCents.value > 0) return 'group__net--income'
  if (netCents.value < 0) return 'group__net--expense'
  return ''
})

function handleSelect(transaction: Transaction): void {
  emit('select', transaction)
}

function handleRemove(transaction: Transaction): void {
  emit('remove', transaction)
}
</script>

<template>
  <view class="group">
    <view class="group__head">
      <text class="group__date">
        {{ dayLabel(group.date) }} {{ weekdayLabel(group.date) }}
      </text>
      <text class="group__net" :class="netClass">
        {{ formatSignedYuan(netCents) }}
      </text>
    </view>

    <view class="group__card">
      <TransactionItem
        v-for="(transaction, index) in group.transactions"
        :key="transaction.id"
        :transaction="transaction"
        :is-last="index === group.transactions.length - 1"
        @select="handleSelect"
        @longpress="handleRemove"
      />
    </view>
  </view>
</template>

<style lang="scss" scoped>
.group {
  padding: 0 32rpx 24rpx;

  &__head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16rpx 8rpx;
  }

  &__date {
    font-size: 26rpx;
    font-weight: 500;
    color: var(--color-text-secondary);
  }

  &__net {
    font-size: 26rpx;
    font-weight: 600;
    color: var(--color-text-secondary);

    &--income {
      color: var(--color-income);
    }

    &--expense {
      color: var(--color-expense);
    }
  }

  &__card {
    overflow: hidden;
    background-color: var(--color-surface);
    border-radius: var(--radius-card);
    box-shadow: var(--shadow-card);
  }
}
</style>
