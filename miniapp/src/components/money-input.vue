<script setup lang="ts">
import type { TransactionType } from '@/models/types'

defineProps<{
  modelValue: string
  type: TransactionType
  disabled?: boolean
}>()

const emit = defineEmits<{
  (event: 'update:modelValue', value: string): void
}>()

function onInput(event: Event): void {
  const detail = (event as unknown as { detail: { value: string } }).detail
  emit('update:modelValue', detail.value)
}
</script>

<template>
  <view class="amount">
    <text
      class="amount__sign"
      :class="
        type === 'expense' ? 'amount__sign--expense' : 'amount__sign--income'
      "
    >
      {{ type === 'expense' ? '-' : '+' }}
    </text>
    <input
      class="amount__input"
      type="digit"
      :value="modelValue"
      :disabled="disabled"
      placeholder="0.00"
      placeholder-style="color: #8b8ba3"
      @input="onInput"
    />
  </view>
</template>

<style lang="scss" scoped>
.amount {
  display: flex;
  align-items: center;
  padding: 8rpx 28rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-control);

  &__sign {
    font-size: 44rpx;
    font-weight: 700;

    &--expense {
      color: var(--color-expense);
    }

    &--income {
      color: var(--color-income);
    }
  }

  &__input {
    flex: 1;
    height: 96rpx;
    margin-left: 16rpx;
    font-size: 44rpx;
    font-weight: 700;
    color: var(--color-text);
  }
}
</style>
