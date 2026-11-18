<script setup lang="ts">
defineProps<{
  text: string
  hint?: string
}>()
</script>

<template>
  <view class="empty">
    <text class="empty__text">{{ text }}</text>
    <text v-if="hint" class="empty__hint">{{ hint }}</text>
  </view>
</template>

<style lang="scss" scoped>
.empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 96rpx 48rpx;

  &__text {
    font-size: 28rpx;
    color: var(--color-text-tertiary);
  }

  &__hint {
    margin-top: 12rpx;
    font-size: 24rpx;
    color: var(--color-text-tertiary);
  }
}
</style>
