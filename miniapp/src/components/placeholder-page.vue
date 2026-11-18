<script setup lang="ts">
defineProps<{
  badge: string
  title: string
  description: string
}>()
</script>

<template>
  <view class="placeholder">
    <view class="placeholder__badge">{{ badge }}</view>
    <text class="placeholder__title">{{ title }}</text>
    <text class="placeholder__description">{{ description }}</text>
    <text class="placeholder__hint">将在后续批次实现</text>
    <slot />
  </view>
</template>

<style lang="scss" scoped>
.placeholder {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 70vh;
  padding: 48rpx;

  &__badge {
    padding: 10rpx 28rpx;
    margin-bottom: 28rpx;
    font-size: 24rpx;
    color: var(--color-primary-deep);
    background-color: var(--color-primary-soft);
    border-radius: 999rpx;
  }

  &__title {
    font-size: 40rpx;
    font-weight: 600;
    color: var(--color-text);
  }

  &__description {
    margin-top: 16rpx;
    font-size: 28rpx;
    color: var(--color-text-secondary);
    text-align: center;
  }

  &__hint {
    margin-top: 12rpx;
    font-size: 24rpx;
    color: var(--color-text-tertiary);
  }
}
</style>
