<script setup lang="ts">
import { computed } from 'vue'

import PlaceholderPage from '@/components/placeholder-page.vue'
import { session } from '@/stores/session'

const displayName = computed(() => session.user?.display_name || '当前用户')
</script>

<template>
  <view class="page">
    <PlaceholderPage
      badge="记账"
      title="首页建设中"
      :description="`已登录：${displayName}`"
    />
  </view>
</template>

<style lang="scss" scoped>
.page {
  padding: 32rpx;
}
</style>
