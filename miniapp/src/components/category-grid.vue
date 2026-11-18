<script setup lang="ts">
import { computed } from 'vue'

import type { Category } from '@/models/types'
import { hexToRgba } from '@/utils/color'

const props = defineProps<{
  categories: Category[]
  modelValue: number | null
}>()

const emit = defineEmits<{
  (event: 'update:modelValue', value: number): void
}>()

function itemStyle(category: Category): Record<string, string> {
  if (category.id !== props.modelValue) {
    return {}
  }
  return {
    backgroundColor: hexToRgba(category.color, 0.18),
    borderColor: category.color,
  }
}

function handleSelect(category: Category): void {
  emit('update:modelValue', category.id)
}
</script>

<template>
  <view class="grid">
    <view
      v-for="category in categories"
      :key="category.id"
      class="grid__item"
      :class="{ 'grid__item--active': category.id === modelValue }"
      :style="itemStyle(category)"
      @tap="handleSelect(category)"
    >
      <text class="grid__icon">{{ category.icon }}</text>
      <text class="grid__name">{{ category.name }}</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.grid {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;

  &__item {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    width: 23%;
    margin-bottom: 16rpx;
    padding: 20rpx 8rpx;
    background-color: var(--color-surface-muted);
    border: 2rpx solid transparent;
    border-radius: 20rpx;

    &--active {
      border-width: 2rpx;
    }
  }

  &__icon {
    font-size: 44rpx;
    line-height: 1.2;
  }

  &__name {
    margin-top: 8rpx;
    overflow: hidden;
    max-width: 100%;
    font-size: 24rpx;
    color: var(--color-text-secondary);
    text-overflow: ellipsis;
    white-space: nowrap;
  }
}
</style>
