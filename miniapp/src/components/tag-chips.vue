<script setup lang="ts">
import type { CategoryTag } from '@/models/types'

const props = defineProps<{
  tags: CategoryTag[]
  modelValue: number[]
}>()

const emit = defineEmits<{
  (event: 'update:modelValue', value: number[]): void
}>()

function toggle(tag: CategoryTag): void {
  const next = props.modelValue.includes(tag.id)
    ? props.modelValue.filter((id) => id !== tag.id)
    : [...props.modelValue, tag.id]
  emit('update:modelValue', next)
}
</script>

<template>
  <view class="chips">
    <view
      v-for="tag in tags"
      :key="tag.id"
      class="chip"
      :class="{ 'chip--active': modelValue.includes(tag.id) }"
      @tap="toggle(tag)"
    >
      <text class="chip__text">{{ tag.name }}</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.chips {
  display: flex;
  flex-wrap: wrap;
}

.chip {
  margin: 0 16rpx 16rpx 0;
  padding: 12rpx 28rpx;
  background-color: var(--color-surface-muted);
  border: 2rpx solid transparent;
  border-radius: 999rpx;

  &--active {
    background-color: var(--color-primary);
    border-color: var(--color-primary);
  }

  &__text {
    font-size: 26rpx;
    color: var(--color-text-secondary);
  }

  &--active &__text {
    color: #ffffff;
  }
}
</style>
