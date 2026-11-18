<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'

import type { AuthStatus } from '@/models/types'
import {
  fetchAuthStatus,
  isLoggedIn,
  loginWithPassword,
  loginWithWechat,
  registerAccount,
} from '@/stores/session'

const status = ref<AuthStatus | null>(null)
const loadingStatus = ref(true)
const submitting = ref(false)
const showPasswordForm = ref(false)
const isRegister = ref(false)
const agreed = ref(false)

const form = reactive({
  username: '',
  password: '',
  displayName: '',
  inviteCode: '',
})

const wechatEnabled = computed(
  () => status.value?.wechat_login_configured === true,
)
const registrationOpen = computed(
  () => status.value?.registration_open !== false,
)

onLoad(() => {
  if (isLoggedIn()) {
    uni.switchTab({ url: '/pages/home/index' })
    return
  }
  loadStatus()
})

async function loadStatus(): Promise<void> {
  try {
    status.value = await fetchAuthStatus()
  } catch {
    status.value = {
      has_users: false,
      registration_open: true,
      invite_code_required: false,
      wechat_login_configured: false,
    }
  } finally {
    loadingStatus.value = false
    if (!wechatEnabled.value) {
      showPasswordForm.value = true
    }
  }
}

function ensureAgreed(): boolean {
  if (agreed.value) {
    return true
  }
  uni.showToast({ title: '请先阅读并同意隐私政策', icon: 'none' })
  return false
}

function toHome(): void {
  uni.switchTab({ url: '/pages/home/index' })
}

function errorMessage(error: unknown): string {
  if (error instanceof Error && error.message) {
    return error.message
  }
  return '操作失败，请重试'
}

async function handleWechatLogin(): Promise<void> {
  if (!ensureAgreed() || submitting.value) {
    return
  }
  submitting.value = true
  try {
    await loginWithWechat()
    toHome()
  } catch (error) {
    uni.showToast({ title: errorMessage(error), icon: 'none' })
    showPasswordForm.value = true
  } finally {
    submitting.value = false
  }
}

async function handlePasswordSubmit(): Promise<void> {
  if (!ensureAgreed() || submitting.value) {
    return
  }
  const username = form.username.trim()
  const password = form.password
  if (!username || !password) {
    uni.showToast({ title: '请输入用户名和密码', icon: 'none' })
    return
  }
  submitting.value = true
  try {
    if (isRegister.value) {
      await registerAccount(
        username,
        password,
        form.displayName.trim(),
        form.inviteCode.trim(),
      )
    } else {
      await loginWithPassword(username, password)
    }
    toHome()
  } catch (error) {
    uni.showToast({ title: errorMessage(error), icon: 'none' })
  } finally {
    submitting.value = false
  }
}

function togglePasswordForm(): void {
  showPasswordForm.value = !showPasswordForm.value
}

function toggleRegister(): void {
  if (!registrationOpen.value) {
    uni.showToast({ title: '当前未开放注册', icon: 'none' })
    return
  }
  isRegister.value = !isRegister.value
}

function openPrivacy(): void {
  uni.navigateTo({ url: '/pages/privacy/index' })
}
</script>

<template>
  <view class="login">
    <view class="login__glow login__glow--top" />
    <view class="login__glow login__glow--bottom" />

    <view class="login__hero">
      <image class="login__logo" src="/static/app-icon.png" mode="aspectFit" />
      <text class="login__title">记账</text>
      <text class="login__subtitle">每一笔，都心中有数</text>
    </view>

    <view class="login__card">
      <view v-if="loadingStatus" class="login__loading">正在检查登录方式…</view>

      <template v-else>
        <button
          v-if="wechatEnabled && !showPasswordForm"
          class="btn btn--primary"
          :loading="submitting"
          :disabled="submitting"
          @tap="handleWechatLogin"
        >
          微信一键登录
        </button>

        <button
          v-if="wechatEnabled && showPasswordForm"
          class="btn btn--primary"
          @tap="togglePasswordForm"
        >
          返回微信登录
        </button>

        <view v-if="showPasswordForm || !wechatEnabled" class="form">
          <input
            v-model="form.username"
            class="form__input"
            type="text"
            placeholder="用户名"
            placeholder-class="form__placeholder"
          />
          <input
            v-model="form.password"
            class="form__input"
            password
            placeholder="密码（至少 6 位）"
            placeholder-class="form__placeholder"
          />
          <input
            v-if="isRegister"
            v-model="form.displayName"
            class="form__input"
            type="text"
            placeholder="昵称（选填）"
            placeholder-class="form__placeholder"
          />
          <input
            v-if="isRegister && status?.invite_code_required"
            v-model="form.inviteCode"
            class="form__input"
            type="text"
            placeholder="邀请码"
            placeholder-class="form__placeholder"
          />

          <button
            class="btn btn--primary"
            :loading="submitting"
            :disabled="submitting"
            @tap="handlePasswordSubmit"
          >
            {{ isRegister ? '注册并登录' : '登录' }}
          </button>

          <text
            v-if="registrationOpen"
            class="form__switch"
            @tap="toggleRegister"
          >
            {{ isRegister ? '已有账号，去登录' : '没有账号？注册一个' }}
          </text>
          <text v-else class="form__hint">当前未开放注册，请联系管理员</text>
        </view>
      </template>

      <view class="privacy">
        <view
          class="privacy__check"
          :class="{ 'privacy__check--on': agreed }"
          @tap="agreed = !agreed"
        >
          <text v-if="agreed" class="privacy__tick">✓</text>
        </view>
        <text class="privacy__text">我已阅读并同意</text>
        <text class="privacy__link" @tap="openPrivacy">
          《用户协议与隐私政策》
        </text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.login {
  position: relative;
  min-height: 100vh;
  padding: calc(var(--status-bar-height) + 96rpx) 48rpx 64rpx;
  overflow: hidden;
  background: linear-gradient(180deg, #eef0ff 0%, #f4f5fb 46%, #f4f5fb 100%);

  &__glow {
    position: absolute;
    border-radius: 50%;
    filter: blur(10rpx);

    &--top {
      top: -180rpx;
      right: -140rpx;
      width: 520rpx;
      height: 520rpx;
      background: rgba(99, 102, 241, 0.18);
    }

    &--bottom {
      bottom: -220rpx;
      left: -180rpx;
      width: 560rpx;
      height: 560rpx;
      background: rgba(129, 140, 248, 0.12);
    }
  }

  &__hero {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    margin-bottom: 72rpx;
  }

  &__logo {
    width: 152rpx;
    height: 152rpx;
    border-radius: 36rpx;
    box-shadow: 0 20rpx 48rpx rgba(67, 56, 202, 0.18);
  }

  &__title {
    margin-top: 28rpx;
    font-size: 52rpx;
    font-weight: 700;
    letter-spacing: 4rpx;
    color: var(--color-text);
  }

  &__subtitle {
    margin-top: 12rpx;
    font-size: 26rpx;
    color: var(--color-text-secondary);
  }

  &__card {
    position: relative;
    padding: 48rpx 40rpx 36rpx;
    background-color: var(--color-surface);
    border-radius: 36rpx;
    box-shadow: var(--shadow-card);
  }

  &__loading {
    padding: 24rpx 0;
    font-size: 28rpx;
    color: var(--color-text-secondary);
    text-align: center;
  }
}

.btn {
  width: 100%;
  height: 96rpx;
  font-size: 30rpx;
  font-weight: 600;
  line-height: 96rpx;
  border-radius: var(--radius-control);

  &::after {
    border: none;
  }

  &--primary {
    color: #ffffff;
    background: linear-gradient(135deg, #6366f1 0%, #4338ca 100%);
    box-shadow: 0 14rpx 32rpx rgba(67, 56, 202, 0.24);

    &[disabled] {
      color: rgba(255, 255, 255, 0.82);
      background: linear-gradient(135deg, #a5b4fc 0%, #818cf8 100%);
    }
  }
}

.form {
  display: flex;
  flex-direction: column;
  margin-top: 32rpx;

  > * + * {
    margin-top: 24rpx;
  }

  &__input {
    height: 96rpx;
    padding: 0 28rpx;
    font-size: 28rpx;
    color: var(--color-text);
    background-color: var(--color-surface-muted);
    border-radius: var(--radius-control);
  }

  &__placeholder {
    color: var(--color-text-tertiary);
  }

  &__switch {
    font-size: 26rpx;
    color: var(--color-primary-deep);
    text-align: center;
  }

  &__hint {
    font-size: 24rpx;
    color: var(--color-text-tertiary);
    text-align: center;
  }
}

.privacy {
  display: flex;
  align-items: center;
  justify-content: center;
  margin-top: 36rpx;

  &__check {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32rpx;
    height: 32rpx;
    margin-right: 12rpx;
    border: 2rpx solid var(--color-border);
    border-radius: 8rpx;

    &--on {
      background-color: var(--color-primary);
      border-color: var(--color-primary);
    }
  }

  &__tick {
    font-size: 22rpx;
    line-height: 1;
    color: #ffffff;
  }

  &__text {
    font-size: 24rpx;
    color: var(--color-text-secondary);
  }

  &__link {
    font-size: 24rpx;
    color: var(--color-primary-deep);
  }
}
</style>
