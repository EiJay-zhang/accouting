<script setup lang="ts">
import { computed } from 'vue'

import type { Transaction } from '@/models/types'
import { hexToRgba } from '@/utils/color'
import { formatYuan } from '@/utils/money'

const props = defineProps<{
  transaction: Transaction
  isLast?: boolean
}>()

const emit = defineEmits<{
  (event: 'select', transaction: Transaction): void
  (event: 'longpress', transaction: Transaction): void
}>()

const isExpense = computed(() => props.transaction.type === 'expense')

const subtitle = computed(() => {
  const names = props.transaction.tags.map((tag) => tag.name)
  if (!names.length) {
    return props.transaction.category.name
  }
  return `${props.transaction.category.name} · ${names.join(' · ')}`
})

const iconStyle = computed(() => ({
  backgroundColor: hexToRgba(props.transaction.category.color, 0.18),
}))

function handleSelect(): void {
  emit('select', props.transaction)
}

function handleLongPress(): void {
  emit('longpress', props.transaction)
}
</script>

<template>
  <view
    class="item"
    :class="{ 'item--last': isLast }"
    @tap="handleSelect"
    @longpress="handleLongPress"
  >
    <view class="item__icon" :style="iconStyle">
      <text class="item__emoji">{{ transaction.category.icon }}</text>
    </view>
    <view class="item__body">
      <text class="item__title">{{ transaction.title }}</text>
      <text class="item__subtitle">{{ subtitle }}</text>
    </view>
    <text
      class="item__amount"
      :class="
        isExpense ? 'item__amount--expense' : 'item__amount--income'
      "
    >
      {{ isExpense ? '-' : '+' }}¥{{ formatYuan(transaction.amountCents) }}
    </text>
  </view>
</template>

<style lang="scss" scoped>
.item {
  display: flex;
  align-items: center;
  padding: 24rpx 28rpx;
  border-bottom: 1rpx solid rgba(228, 230, 240, 0.6);

  &--last {
    border-bottom: none;
  }

  &__icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 76rpx;
    height: 76rpx;
    border-radius: 20rpx;
  }

  &__emoji {
    font-size: 38rpx;
    line-height: 1;
  }

  &__body {
    display: flex;
    flex: 1;
    flex-direction: column;
    min-width: 0;
    margin-left: 24rpx;
  }

  &__title {
    overflow: hidden;
    font-size: 28rpx;
    font-weight: 600;
    color: var(--color-text);
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  &__subtitle {
    margin-top: 6rpx;
    overflow: hidden;
    font-size: 24rpx;
    color: var(--color-text-tertiary);
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  &__amount {
    margin-left: 16rpx;
    font-size: 30rpx;
    font-weight: 600;

    &--expense {
      color: var(--color-expense);
    }

    &--income {
      color: var(--color-income);
    }
  }
}
</style>
