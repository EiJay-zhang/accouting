<script setup lang="ts">
import { computed } from 'vue'

import PlaceholderPage from '@/components/placeholder-page.vue'
import { logout, session } from '@/stores/session'

const displayName = computed(() => session.user?.display_name || '当前用户')
const roleText = computed(() => (session.user?.is_admin ? ' · 管理员' : ''))

async function handleLogout(): Promise<void> {
  await logout()
  uni.reLaunch({ url: '/pages/login/index' })
}
</script>

<template>
  <view class="page">
    <PlaceholderPage
      badge="我的"
      title="个人中心建设中"
      :description="`${displayName}${roleText}`"
    >
      <button class="logout" @tap="handleLogout">退出登录</button>
    </PlaceholderPage>
  </view>
</template>

<style lang="scss" scoped>
.page {
  padding: 32rpx;
}

.logout {
  margin-top: 56rpx;
  width: 100%;
  height: 88rpx;
  font-size: 28rpx;
  line-height: 88rpx;
  color: var(--color-danger);
  background-color: var(--color-surface);
  border: 2rpx solid var(--color-border);
  border-radius: var(--radius-control);

  &::after {
    border: none;
  }
}
</style>
