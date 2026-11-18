<script setup lang="ts">
import { computed, ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'

import {
  createUser,
  deleteUser,
  fetchUsers,
  updateProfile,
} from '@/api/account'
import type { AppUser } from '@/models/types'
import { session, updateSessionUser } from '@/stores/session'
import { showConfirm } from '@/utils/confirm'
import { errorMessage } from '@/utils/error'

const displayName = ref(session.user?.display_name || '')
const currentPassword = ref('')
const newPassword = ref('')
const users = ref<AppUser[]>([])
const loadingUsers = ref(false)
const saving = ref(false)

const creating = ref(false)
const createForm = ref({ username: '', password: '', displayName: '' })
const creatingBusy = ref(false)

const isAdmin = computed(() => Boolean(session.user?.is_admin))
const currentId = computed(() => session.user?.id ?? 0)
const initial = computed(() => {
  const name = (session.user?.display_name || '').trim()
  return name ? Array.from(name)[0].toUpperCase() : '?'
})

onShow(() => {
  if (!isAdmin.value) {
    return
  }
  void loadUsers()
})

async function loadUsers(): Promise<void> {
  loadingUsers.value = true
  try {
    users.value = await fetchUsers()
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  } finally {
    loadingUsers.value = false
  }
}

async function saveName(): Promise<void> {
  const name = displayName.value.trim()
  if (!name) {
    uni.showToast({ title: '请填写昵称', icon: 'none' })
    return
  }
  saving.value = true
  try {
    const user = await updateProfile({ display_name: name })
    updateSessionUser(user)
    displayName.value = user.display_name
    uni.showToast({ title: '昵称已保存', icon: 'none' })
    if (isAdmin.value) {
      await loadUsers()
    }
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  } finally {
    saving.value = false
  }
}

async function savePassword(): Promise<void> {
  if (!currentPassword.value) {
    uni.showToast({ title: '请填写当前密码', icon: 'none' })
    return
  }
  if (newPassword.value.length < 6) {
    uni.showToast({ title: '新密码至少 6 位', icon: 'none' })
    return
  }
  saving.value = true
  try {
    const user = await updateProfile({
      current_password: currentPassword.value,
      new_password: newPassword.value,
    })
    updateSessionUser(user)
    currentPassword.value = ''
    newPassword.value = ''
    uni.showToast({ title: '密码已更新', icon: 'none' })
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  } finally {
    saving.value = false
  }
}

function openCreate(): void {
  createForm.value = { username: '', password: '', displayName: '' }
  creating.value = true
}

function closeCreate(): void {
  if (creatingBusy.value) {
    return
  }
  creating.value = false
}

async function submitCreate(): Promise<void> {
  const username = createForm.value.username.trim()
  const password = createForm.value.password
  if (!username) {
    uni.showToast({ title: '请填写用户名', icon: 'none' })
    return
  }
  if (password.length < 6) {
    uni.showToast({ title: '密码至少 6 位', icon: 'none' })
    return
  }
  creatingBusy.value = true
  try {
    await createUser({
      username,
      password,
      display_name: createForm.value.displayName.trim() || undefined,
    })
    creating.value = false
    uni.showToast({ title: '账号已创建', icon: 'none' })
    await loadUsers()
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  } finally {
    creatingBusy.value = false
  }
}

async function removeUser(user: AppUser): Promise<void> {
  const confirmed = await showConfirm(
    `删除${user.display_name}`,
    '会删除这个账号下的分类、账单、预算和物品。',
    '删除',
  )
  if (!confirmed) {
    return
  }
  try {
    await deleteUser(user.id)
    uni.showToast({ title: '已删除', icon: 'none' })
    await loadUsers()
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  }
}
</script>

<template>
  <view class="page">
    <view class="profile">
      <view class="profile__avatar">
        <text class="profile__initial">{{ initial }}</text>
      </view>
      <view class="profile__info">
        <text class="profile__name">{{ session.user?.display_name }}</text>
        <text class="profile__username">{{ session.user?.username }}</text>
      </view>
      <text v-if="isAdmin" class="profile__badge">管理员</text>
    </view>

    <text class="section">昵称</text>
    <view class="field">
      <input
        v-model="displayName"
        class="field__input"
        placeholder="显示名称"
        placeholder-style="color: #b9b9cb"
        maxlength="20"
      />
    </view>
    <button class="primary-btn" :disabled="saving" @tap="saveName">
      保存昵称
    </button>

    <text class="section">密码</text>
    <view class="field">
      <input
        v-model="currentPassword"
        class="field__input"
        password
        placeholder="当前密码"
        placeholder-style="color: #b9b9cb"
      />
    </view>
    <view class="field">
      <input
        v-model="newPassword"
        class="field__input"
        password
        placeholder="新密码"
        placeholder-style="color: #b9b9cb"
      />
    </view>
    <text class="hint">新密码至少 6 位。</text>
    <button class="primary-btn" :disabled="saving" @tap="savePassword">
      更新密码
    </button>

    <template v-if="isAdmin">
      <view class="section-row">
        <text class="section section--inline">全部账号</text>
        <view class="section-row__action" @tap="openCreate">
          <text class="section-row__action-text">＋ 新建</text>
        </view>
      </view>

      <view v-if="loadingUsers" class="state">
        <text class="state__text">加载中…</text>
      </view>

      <view v-else class="accounts">
        <view v-for="user in users" :key="user.id" class="account">
          <view class="account__avatar">
            <text class="account__initial">
              {{ (user.display_name || user.username).slice(0, 1) }}
            </text>
          </view>
          <view class="account__info">
            <view class="account__name-row">
              <text class="account__name">{{ user.display_name }}</text>
              <text v-if="user.id === currentId" class="account__badge">当前</text>
              <text v-else-if="user.is_admin" class="account__badge account__badge--admin">
                管理员
              </text>
            </view>
            <text class="account__username">@{{ user.username }}</text>
          </view>
          <view
            v-if="user.id !== currentId"
            class="account__delete"
            @tap="removeUser(user)"
          >
            <text class="account__delete-text">删除</text>
          </view>
        </view>
      </view>
    </template>

    <view class="page__bottom" />

    <view v-if="creating" class="mask" @tap="closeCreate">
      <view class="dialog" @tap.stop>
        <text class="dialog__title">新建账号</text>
        <text class="dialog__desc">新账号有自己的分类和账单。</text>
        <view class="field field--dialog">
          <input
            v-model="createForm.username"
            class="field__input"
            placeholder="用户名"
            placeholder-style="color: #b9b9cb"
          />
        </view>
        <view class="field field--dialog">
          <input
            v-model="createForm.displayName"
            class="field__input"
            placeholder="昵称，可不填"
            placeholder-style="color: #b9b9cb"
          />
        </view>
        <view class="field field--dialog">
          <input
            v-model="createForm.password"
            class="field__input"
            password
            placeholder="密码，至少 6 位"
            placeholder-style="color: #b9b9cb"
          />
        </view>
        <view class="dialog__actions">
          <button class="dialog__btn" @tap="closeCreate">取消</button>
          <button
            class="dialog__btn dialog__btn--primary"
            :disabled="creatingBusy"
            @tap="submitCreate"
          >
            创建
          </button>
        </view>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.page {
  min-height: 100vh;
  padding: 24rpx 40rpx 0;

  &__bottom {
    height: calc(60rpx + env(safe-area-inset-bottom));
  }
}

.profile {
  display: flex;
  align-items: center;
  padding: 32rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);

  &__avatar {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 96rpx;
    height: 96rpx;
    margin-right: 24rpx;
    background-color: var(--color-primary);
    border-radius: 26rpx;
  }

  &__initial {
    font-size: 40rpx;
    font-weight: 700;
    color: #ffffff;
  }

  &__info {
    display: flex;
    flex: 1;
    flex-direction: column;
  }

  &__name {
    font-size: 34rpx;
    font-weight: 700;
    color: var(--color-text);
  }

  &__username {
    margin-top: 6rpx;
    font-size: 24rpx;
    color: var(--color-text-tertiary);
  }

  &__badge {
    padding: 4rpx 16rpx;
    font-size: 20rpx;
    color: var(--color-primary-deep);
    background-color: var(--color-primary-soft);
    border-radius: 999rpx;
  }
}

.section {
  display: block;
  margin-top: 36rpx;
  padding: 0 4rpx 12rpx;
  font-size: 26rpx;
  font-weight: 600;
  color: var(--color-text-secondary);

  &--inline {
    margin-top: 0;
    padding-bottom: 0;
  }
}

.section-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 44rpx;
  padding: 0 4rpx 12rpx;

  &__action {
    padding: 4rpx 12rpx;
  }

  &__action-text {
    font-size: 26rpx;
    font-weight: 600;
    color: var(--color-primary);
  }
}

.field {
  padding: 0 28rpx;
  margin-bottom: 16rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-control);

  &--dialog {
    margin-bottom: 12rpx;
    background-color: var(--color-surface-muted);
  }

  &__input {
    height: 92rpx;
    font-size: 28rpx;
    color: var(--color-text);
  }
}

.hint {
  display: block;
  padding: 0 8rpx;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
}

.primary-btn {
  width: 100%;
  height: 84rpx;
  margin-top: 20rpx;
  font-size: 28rpx;
  font-weight: 600;
  line-height: 84rpx;
  color: #ffffff;
  background-color: var(--color-primary);
  border-radius: var(--radius-control);

  &::after {
    border: none;
  }

  &[disabled] {
    opacity: 0.6;
  }
}

.state {
  padding: 48rpx 0;
  text-align: center;

  &__text {
    font-size: 26rpx;
    color: var(--color-text-tertiary);
  }
}

.accounts {
  background-color: var(--color-surface);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);
  overflow: hidden;
}

.account {
  display: flex;
  align-items: center;
  padding: 24rpx 28rpx;

  & + & {
    border-top: 1rpx solid var(--color-border);
  }

  &__avatar {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 72rpx;
    height: 72rpx;
    margin-right: 20rpx;
    background-color: var(--color-surface-muted);
    border-radius: 20rpx;
  }

  &__initial {
    font-size: 30rpx;
    font-weight: 700;
    color: var(--color-primary-deep);
  }

  &__info {
    display: flex;
    flex: 1;
    flex-direction: column;
  }

  &__name-row {
    display: flex;
    align-items: center;
  }

  &__name {
    font-size: 28rpx;
    font-weight: 600;
    color: var(--color-text);
  }

  &__badge {
    margin-left: 12rpx;
    padding: 2rpx 12rpx;
    font-size: 20rpx;
    color: var(--color-primary-deep);
    background-color: var(--color-primary-soft);
    border-radius: 999rpx;

    &--admin {
      color: var(--color-warning);
      background-color: rgba(245, 158, 11, 0.12);
    }
  }

  &__username {
    margin-top: 4rpx;
    font-size: 22rpx;
    color: var(--color-text-tertiary);
  }

  &__delete {
    padding: 8rpx 18rpx;
  }

  &__delete-text {
    font-size: 24rpx;
    color: var(--color-danger);
  }
}

.mask {
  position: fixed;
  inset: 0;
  z-index: 20;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 56rpx;
  background-color: rgba(26, 26, 46, 0.45);
}

.dialog {
  width: 100%;
  padding: 40rpx 32rpx 32rpx;
  background-color: var(--color-surface);
  border-radius: 28rpx;

  &__title {
    display: block;
    font-size: 34rpx;
    font-weight: 700;
    color: var(--color-text);
  }

  &__desc {
    display: block;
    margin-top: 8rpx;
    margin-bottom: 24rpx;
    font-size: 24rpx;
    color: var(--color-text-tertiary);
  }

  &__actions {
    display: flex;
    margin-top: 24rpx;
  }

  &__btn {
    flex: 1;
    height: 80rpx;
    margin: 0 8rpx;
    font-size: 28rpx;
    font-weight: 600;
    line-height: 80rpx;
    color: var(--color-text-secondary);
    background-color: var(--color-surface-muted);
    border-radius: var(--radius-control);

    &::after {
      border: none;
    }

    &--primary {
      color: #ffffff;
      background-color: var(--color-primary);
    }
  }
}
</style>
