<script setup lang="ts">
import { computed } from 'vue'

import { downloadTransactionsXlsx } from '@/api/export'
import { deleteAccount, logout, session } from '@/stores/session'
import { errorMessage } from '@/utils/error'
import { showConfirm } from '@/utils/confirm'

const APP_VERSION = '1.0.0'

const displayName = computed(() => session.user?.display_name || '当前用户')
const username = computed(() => session.user?.username || '')
const isAdmin = computed(() => Boolean(session.user?.is_admin))
const initial = computed(() => {
  const name = displayName.value.trim()
  return name ? Array.from(name)[0].toUpperCase() : '?'
})

let exporting = false

function openPage(url: string): void {
  uni.navigateTo({ url })
}

async function handleExport(): Promise<void> {
  if (exporting) {
    return
  }
  exporting = true
  uni.showLoading({ title: '导出中…', mask: true })
  try {
    const filePath = await downloadTransactionsXlsx()
    uni.hideLoading()
    // #ifdef H5
    const link = document.createElement('a')
    link.href = filePath
    link.download = 'transactions.xlsx'
    link.click()
    // #endif
    // #ifndef H5
    uni.openDocument({
      filePath,
      fileType: 'xlsx',
      showMenu: true,
      fail: () => {
        uni.showToast({ title: '文件已下载，但无法打开', icon: 'none' })
      },
    })
    // #endif
  } catch (err) {
    uni.hideLoading()
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  } finally {
    exporting = false
  }
}

async function handleLogout(): Promise<void> {
  const confirmed = await showConfirm(
    '退出登录',
    '退出后需要重新登录才能查看账本。',
    '退出登录',
  )
  if (!confirmed) {
    return
  }
  await logout()
  uni.reLaunch({ url: '/pages/login/index' })
}

function handleDeleteAccount(): void {
  uni.showModal({
    title: '注销账号',
    content:
      '注销后，账号下的账单、分类、标签、预算和物品将被永久删除且无法恢复。',
    confirmText: '继续',
    cancelText: '取消',
    confirmColor: '#dc2626',
    success: (first) => {
      if (!first.confirm) {
        return
      }
      uni.showModal({
        title: '确认注销',
        editable: true,
        placeholderText: '请输入「注销」确认',
        confirmText: '注销账号',
        cancelText: '取消',
        confirmColor: '#dc2626',
        success: (second) => {
          if (!second.confirm) {
            return
          }
          if ((second.content || '').trim() !== '注销') {
            uni.showToast({ title: '输入不正确，已取消', icon: 'none' })
            return
          }
          void submitDeleteAccount()
        },
      })
    },
  })
}

async function submitDeleteAccount(): Promise<void> {
  try {
    await deleteAccount()
    uni.reLaunch({ url: '/pages/login/index' })
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  }
}
</script>

<template>
  <view class="settings">
    <text class="settings__title">我的</text>

    <view class="profile" @tap="openPage('/pages/user-manage/index')">
      <view class="profile__avatar">
        <text class="profile__initial">{{ initial }}</text>
      </view>
      <view class="profile__info">
        <text class="profile__name">{{ displayName }}</text>
        <view class="profile__meta">
          <text class="profile__username">@{{ username }}</text>
          <text v-if="isAdmin" class="profile__badge">管理员</text>
        </view>
      </view>
      <text class="profile__arrow">›</text>
    </view>

    <view class="group">
      <text class="group__title">账本</text>
      <view class="menu">
        <view class="menu__item" @tap="openPage('/pages/category-manage/index')">
          <view class="menu__icon">📂</view>
          <view class="menu__text">
            <text class="menu__label">分类管理</text>
            <text class="menu__hint">分别管理收入和支出分类</text>
          </view>
          <text class="menu__arrow">›</text>
        </view>
        <view class="menu__divider" />
        <view class="menu__item" @tap="openPage('/pages/tag-manage/index')">
          <view class="menu__icon">🏷️</view>
          <view class="menu__text">
            <text class="menu__label">标签设置</text>
            <text class="menu__hint">标签会记在账单上，方便搜索</text>
          </view>
          <text class="menu__arrow">›</text>
        </view>
        <view class="menu__divider" />
        <view class="menu__item" @tap="openPage('/pages/bill-import/index')">
          <view class="menu__icon">📥</view>
          <view class="menu__text">
            <text class="menu__label">导入账单</text>
            <text class="menu__hint">从微信聊天选择支付宝 / 微信 / 银行账单文件</text>
          </view>
          <text class="menu__arrow">›</text>
        </view>
        <view class="menu__divider" />
        <view class="menu__item" @tap="handleExport">
          <view class="menu__icon">📤</view>
          <view class="menu__text">
            <text class="menu__label">导出 XLSX</text>
            <text class="menu__hint">导出全部账单，可打开或转发给好友</text>
          </view>
          <text class="menu__arrow">›</text>
        </view>
      </view>
    </view>

    <view class="group">
      <text class="group__title">账号</text>
      <view class="menu">
        <view class="menu__item" @tap="openPage('/pages/user-manage/index')">
          <view class="menu__icon">👤</view>
          <view class="menu__text">
            <text class="menu__label">账号与资料</text>
            <text class="menu__hint">
              {{ isAdmin ? '修改昵称、密码，管理多账号' : '修改昵称与密码' }}
            </text>
          </view>
          <text class="menu__arrow">›</text>
        </view>
      </view>
    </view>

    <view class="group">
      <text class="group__title">关于</text>
      <view class="menu">
        <view class="menu__item" @tap="openPage('/pages/privacy/index')">
          <view class="menu__icon">🔒</view>
          <view class="menu__text">
            <text class="menu__label">用户协议与隐私政策</text>
          </view>
          <text class="menu__arrow">›</text>
        </view>
        <view class="menu__divider" />
        <view class="menu__item menu__item--static">
          <view class="menu__icon">ℹ️</view>
          <view class="menu__text">
            <text class="menu__label">版本</text>
          </view>
          <text class="menu__version">{{ APP_VERSION }}</text>
        </view>
      </view>
    </view>

    <button class="danger-btn" @tap="handleDeleteAccount">注销账号</button>
    <button class="logout-btn" @tap="handleLogout">退出登录</button>
    <text class="settings__hint">
      注销账号会永久删除账本数据，仅退出登录不会。
    </text>
    <view class="settings__bottom" />
  </view>
</template>

<style lang="scss" scoped>
.settings {
  min-height: 100vh;
  padding: 24rpx 40rpx 0;

  &__title {
    display: block;
    padding: 0 4rpx;
    font-size: 44rpx;
    font-weight: 700;
    color: var(--color-text);
  }

  &__hint {
    display: block;
    margin-top: 20rpx;
    font-size: 22rpx;
    line-height: 1.6;
    color: var(--color-text-tertiary);
    text-align: center;
  }

  &__bottom {
    height: calc(48rpx + env(safe-area-inset-bottom));
  }
}

.profile {
  display: flex;
  align-items: center;
  margin-top: 24rpx;
  padding: 32rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);

  &__avatar {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 104rpx;
    height: 104rpx;
    margin-right: 24rpx;
    background-color: var(--color-primary);
    border-radius: 28rpx;
  }

  &__initial {
    font-size: 44rpx;
    font-weight: 700;
    color: #ffffff;
  }

  &__info {
    display: flex;
    flex: 1;
    flex-direction: column;
  }

  &__name {
    font-size: 36rpx;
    font-weight: 700;
    color: var(--color-text);
  }

  &__meta {
    display: flex;
    align-items: center;
    margin-top: 8rpx;
  }

  &__username {
    font-size: 24rpx;
    color: var(--color-text-tertiary);
  }

  &__badge {
    margin-left: 12rpx;
    padding: 2rpx 14rpx;
    font-size: 20rpx;
    color: var(--color-primary-deep);
    background-color: var(--color-primary-soft);
    border-radius: 999rpx;
  }

  &__arrow {
    font-size: 36rpx;
    color: var(--color-text-tertiary);
  }
}

.group {
  margin-top: 32rpx;

  &__title {
    display: block;
    padding: 0 4rpx 12rpx;
    font-size: 26rpx;
    font-weight: 600;
    color: var(--color-text-secondary);
  }
}

.menu {
  background-color: var(--color-surface);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);
  overflow: hidden;

  &__item {
    display: flex;
    align-items: center;
    padding: 26rpx 28rpx;

    &--static {
      padding-top: 22rpx;
      padding-bottom: 22rpx;
    }
  }

  &__icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 64rpx;
    height: 64rpx;
    margin-right: 20rpx;
    font-size: 32rpx;
    background-color: var(--color-surface-muted);
    border-radius: 18rpx;
  }

  &__text {
    display: flex;
    flex: 1;
    flex-direction: column;
  }

  &__label {
    font-size: 28rpx;
    font-weight: 600;
    color: var(--color-text);
  }

  &__hint {
    margin-top: 4rpx;
    font-size: 22rpx;
    color: var(--color-text-tertiary);
  }

  &__arrow {
    font-size: 32rpx;
    color: var(--color-text-tertiary);
  }

  &__version {
    font-size: 24rpx;
    color: var(--color-text-tertiary);
  }

  &__divider {
    height: 1rpx;
    margin-left: 112rpx;
    background-color: var(--color-border);
  }
}

.danger-btn,
.logout-btn {
  width: 100%;
  height: 88rpx;
  margin-top: 40rpx;
  font-size: 28rpx;
  font-weight: 600;
  line-height: 88rpx;
  border-radius: var(--radius-control);

  &::after {
    border: none;
  }
}

.danger-btn {
  margin-top: 48rpx;
  color: var(--color-danger);
  background-color: var(--color-surface);
  border: 2rpx solid rgba(220, 38, 38, 0.24);
}

.logout-btn {
  margin-top: 20rpx;
  color: var(--color-text-secondary);
  background-color: var(--color-surface);
  border: 2rpx solid var(--color-border);
}
</style>
