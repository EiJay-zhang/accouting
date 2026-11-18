<script setup lang="ts">
import { computed } from 'vue'

import { formatYuan } from '@/utils/money'

const props = defineProps<{
  year: number
  month: number
  incomeCents: number
  expenseCents: number
  balanceCents: number
}>()

const emit = defineEmits<{
  (event: 'prev'): void
  (event: 'next'): void
}>()

const balanceClass = computed(() => {
  if (props.balanceCents > 0) return 'overview__balance--income'
  if (props.balanceCents < 0) return 'overview__balance--expense'
  return ''
})

const balanceText = computed(() => {
  const value = props.balanceCents
  if (value === 0) {
    return '¥0.00'
  }
  return `${value > 0 ? '+' : '-'}¥${formatYuan(Math.abs(value))}`
})
</script>

<template>
  <view class="overview">
    <view class="overview__head">
      <view class="overview__nav" @tap="emit('prev')">
        <text class="overview__arrow">‹</text>
      </view>
      <text class="overview__month">{{ year }}年{{ month }}月</text>
      <view class="overview__nav" @tap="emit('next')">
        <text class="overview__arrow">›</text>
      </view>
      <view class="overview__spacer" />
      <text class="overview__label">结余</text>
    </view>

    <text class="overview__balance" :class="balanceClass">
      {{ balanceText }}
    </text>

    <view class="overview__divider" />

    <view class="overview__flows">
      <view class="overview__flow">
        <text class="overview__flow-label">收入</text>
        <text class="overview__flow-value overview__flow-value--income">
          +¥{{ formatYuan(incomeCents) }}
        </text>
      </view>
      <view class="overview__flow-divider" />
      <view class="overview__flow">
        <text class="overview__flow-label">支出</text>
        <text class="overview__flow-value overview__flow-value--expense">
          -¥{{ formatYuan(expenseCents) }}
        </text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.overview {
  padding: 28rpx 32rpx 8rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);

  &__head {
    display: flex;
    align-items: center;
  }

  &__nav {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 44rpx;
    height: 44rpx;
    border-radius: 50%;
    background-color: var(--color-surface-muted);
  }

  &__arrow {
    font-size: 32rpx;
    line-height: 1;
    color: var(--color-text-secondary);
  }

  &__month {
    margin: 0 16rpx;
    font-size: 26rpx;
    font-weight: 500;
    color: var(--color-text-secondary);
  }

  &__spacer {
    flex: 1;
  }

  &__label {
    font-size: 26rpx;
    color: var(--color-text-tertiary);
  }

  &__balance {
    display: block;
    margin-top: 12rpx;
    font-size: 64rpx;
    font-weight: 700;
    line-height: 1.15;
    color: var(--color-text);

    &--income {
      color: var(--color-income);
    }

    &--expense {
      color: var(--color-expense);
    }
  }

  &__divider {
    height: 1rpx;
    margin-top: 24rpx;
    background-color: var(--color-border);
  }

  &__flows {
    display: flex;
    align-items: center;
    padding: 22rpx 0 26rpx;
  }

  &__flow {
    display: flex;
    flex: 1;
    flex-direction: column;
    align-items: center;
  }

  &__flow-divider {
    width: 1rpx;
    height: 56rpx;
    background-color: var(--color-border);
  }

  &__flow-label {
    font-size: 24rpx;
    color: var(--color-text-secondary);
  }

  &__flow-value {
    margin-top: 8rpx;
    font-size: 32rpx;
    font-weight: 700;

    &--income {
      color: var(--color-income);
    }

    &--expense {
      color: var(--color-expense);
    }
  }
}
</style>
