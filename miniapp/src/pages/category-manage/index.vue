<script setup lang="ts">
import { computed, ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'

import EmptyState from '@/components/empty-state.vue'
import {
  createCategory,
  deleteCategory,
  fetchCategories,
  updateCategory,
} from '@/api/transaction'
import type { Category, TransactionType } from '@/models/types'
import { hexToRgba } from '@/utils/color'
import { showConfirm } from '@/utils/confirm'
import { errorMessage } from '@/utils/error'

const ICONS = [
  '🍜',
  '🍚',
  '☕',
  '🛒',
  '🚌',
  '🚕',
  '🏠',
  '💡',
  '📱',
  '👕',
  '💊',
  '🎮',
  '📚',
  '🎁',
  '✈️',
  '🐱',
  '💰',
  '💼',
  '📈',
  '🧧',
]

const COLORS = [
  '#6366F1',
  '#4338CA',
  '#8B93F2',
  '#B4A0E8',
  '#7EB6E6',
  '#7EC8B8',
  '#16A34A',
  '#E7C07A',
  '#F0B08A',
  '#E7A0B8',
  '#DC2626',
  '#8B8BA3',
]

const activeType = ref<TransactionType>('expense')
const categories = ref<Category[]>([])
const loading = ref(true)

const editorOpen = ref(false)
const editingId = ref<number | null>(null)
const saving = ref(false)
const form = ref({ name: '', icon: ICONS[0], color: COLORS[0] })

const typeOptions: { key: TransactionType; label: string }[] = [
  { key: 'expense', label: '支出' },
  { key: 'income', label: '收入' },
]

const editorTitle = computed(() =>
  editingId.value ? '编辑分类' : '新增分类',
)

onShow(() => {
  void load()
})

async function load(): Promise<void> {
  loading.value = true
  try {
    categories.value = await fetchCategories(activeType.value)
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  } finally {
    loading.value = false
  }
}

function selectType(type: TransactionType): void {
  if (activeType.value === type) {
    return
  }
  activeType.value = type
  void load()
}

function iconBackground(color: string): string {
  return hexToRgba(color, 0.16)
}

function openCreate(): void {
  editingId.value = null
  form.value = { name: '', icon: ICONS[0], color: COLORS[0] }
  editorOpen.value = true
}

function openEdit(category: Category): void {
  editingId.value = category.id
  form.value = {
    name: category.name,
    icon: category.icon,
    color: category.color,
  }
  editorOpen.value = true
}

function closeEditor(): void {
  if (saving.value) {
    return
  }
  editorOpen.value = false
}

async function submit(): Promise<void> {
  const name = form.value.name.trim()
  if (!name) {
    uni.showToast({ title: '请填写分类名称', icon: 'none' })
    return
  }
  saving.value = true
  try {
    if (editingId.value) {
      await updateCategory(editingId.value, {
        name,
        icon: form.value.icon,
        color: form.value.color,
      })
    } else {
      await createCategory({
        name,
        icon: form.value.icon,
        color: form.value.color,
        type: activeType.value,
      })
    }
    editorOpen.value = false
    uni.showToast({ title: '已保存', icon: 'none' })
    await load()
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  } finally {
    saving.value = false
  }
}

async function removeEditing(): Promise<void> {
  if (!editingId.value) {
    return
  }
  const confirmed = await showConfirm(
    '删除分类',
    '已有账单的分类不能删除，删除前请先调整相关账单。',
    '删除',
  )
  if (!confirmed) {
    return
  }
  saving.value = true
  try {
    await deleteCategory(editingId.value)
    editorOpen.value = false
    uni.showToast({ title: '已删除', icon: 'none' })
    await load()
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <view class="page">
    <view class="slider">
      <view
        v-for="item in typeOptions"
        :key="item.key"
        class="slider__item"
        :class="{ 'slider__item--active': activeType === item.key }"
        @tap="selectType(item.key)"
      >
        <text
          class="slider__text"
          :class="{ 'slider__text--active': activeType === item.key }"
        >
          {{ item.label }}
        </text>
      </view>
    </view>

    <view v-if="loading" class="state">
      <text class="state__text">加载中…</text>
    </view>

    <view v-else class="list">
      <view
        v-for="category in categories"
        :key="category.id"
        class="cat"
        @tap="openEdit(category)"
      >
        <view
          class="cat__icon"
          :style="{ backgroundColor: iconBackground(category.color) }"
        >
          <text class="cat__emoji">{{ category.icon }}</text>
        </view>
        <text class="cat__name">{{ category.name }}</text>
        <text class="cat__arrow">›</text>
      </view>
    </view>

    <EmptyState
      v-if="!loading && !categories.length"
      text="还没有分类"
      hint="点击下方按钮新增一个分类"
    />

    <button class="add-btn" @tap="openCreate">＋ 新增分类</button>
    <view class="page__bottom" />

    <view v-if="editorOpen" class="mask" @tap="closeEditor">
      <view class="dialog" @tap.stop>
        <text class="dialog__title">{{ editorTitle }}</text>

        <view class="field">
          <input
            v-model="form.name"
            class="field__input"
            placeholder="分类名称"
            placeholder-style="color: #b9b9cb"
            maxlength="20"
          />
        </view>

        <text class="dialog__label">图标</text>
        <view class="icon-grid">
          <view
            v-for="icon in ICONS"
            :key="icon"
            class="icon-cell"
            :class="{ 'icon-cell--active': form.icon === icon }"
            @tap="form.icon = icon"
          >
            <text class="icon-cell__text">{{ icon }}</text>
          </view>
        </view>

        <text class="dialog__label">颜色</text>
        <view class="color-row">
          <view
            v-for="color in COLORS"
            :key="color"
            class="color-cell"
            :class="{ 'color-cell--active': form.color === color }"
            :style="{ backgroundColor: color }"
            @tap="form.color = color"
          />
        </view>

        <view class="dialog__actions">
          <button class="dialog__btn" @tap="closeEditor">取消</button>
          <button
            class="dialog__btn dialog__btn--primary"
            :disabled="saving"
            @tap="submit"
          >
            保存
          </button>
        </view>
        <view v-if="editingId" class="dialog__danger" @tap="removeEditing">
          <text class="dialog__danger-text">删除该分类</text>
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

.slider {
  display: flex;
  padding: 6rpx;
  background-color: var(--color-surface);
  border-radius: 20rpx;

  &__item {
    display: flex;
    flex: 1;
    align-items: center;
    justify-content: center;
    padding: 14rpx 0;
    border-radius: 16rpx;

    &--active {
      background-color: var(--color-primary);
    }
  }

  &__text {
    font-size: 28rpx;
    font-weight: 600;
    color: var(--color-text-secondary);

    &--active {
      color: #ffffff;
    }
  }
}

.list {
  margin-top: 24rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);
  overflow: hidden;
}

.cat {
  display: flex;
  align-items: center;
  padding: 24rpx 28rpx;

  & + & {
    border-top: 1rpx solid var(--color-border);
  }

  &__icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 72rpx;
    height: 72rpx;
    margin-right: 20rpx;
    border-radius: 20rpx;
  }

  &__emoji {
    font-size: 34rpx;
  }

  &__name {
    flex: 1;
    font-size: 28rpx;
    font-weight: 600;
    color: var(--color-text);
  }

  &__arrow {
    font-size: 30rpx;
    color: var(--color-text-tertiary);
  }
}

.add-btn {
  width: 100%;
  height: 88rpx;
  margin-top: 28rpx;
  font-size: 28rpx;
  font-weight: 600;
  line-height: 88rpx;
  color: var(--color-primary-deep);
  background-color: var(--color-primary-soft);
  border-radius: var(--radius-control);

  &::after {
    border: none;
  }
}

.state {
  padding: 80rpx 0;
  text-align: center;

  &__text {
    font-size: 26rpx;
    color: var(--color-text-tertiary);
  }
}

.mask {
  position: fixed;
  inset: 0;
  z-index: 20;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 40rpx;
  background-color: rgba(26, 26, 46, 0.45);
}

.dialog {
  width: 100%;
  max-height: 88vh;
  overflow-y: auto;
  padding: 40rpx 32rpx 28rpx;
  background-color: var(--color-surface);
  border-radius: 28rpx;

  &__title {
    display: block;
    margin-bottom: 24rpx;
    font-size: 34rpx;
    font-weight: 700;
    color: var(--color-text);
  }

  &__label {
    display: block;
    margin: 28rpx 0 14rpx;
    font-size: 24rpx;
    font-weight: 600;
    color: var(--color-text-secondary);
  }

  &__actions {
    display: flex;
    margin-top: 32rpx;
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

    &[disabled] {
      opacity: 0.6;
    }
  }

  &__danger {
    margin-top: 20rpx;
    padding: 12rpx 0;
    text-align: center;
  }

  &__danger-text {
    font-size: 26rpx;
    color: var(--color-danger);
  }
}

.field {
  padding: 0 24rpx;
  background-color: var(--color-surface-muted);
  border-radius: var(--radius-control);

  &__input {
    height: 88rpx;
    font-size: 28rpx;
    color: var(--color-text);
  }
}

.icon-grid {
  display: flex;
  flex-wrap: wrap;
}

.icon-cell {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 84rpx;
  height: 84rpx;
  margin: 0 10rpx 10rpx 0;
  background-color: var(--color-surface-muted);
  border: 3rpx solid transparent;
  border-radius: 18rpx;

  &--active {
    border-color: var(--color-primary);
    background-color: var(--color-primary-soft);
  }

  &__text {
    font-size: 36rpx;
  }
}

.color-row {
  display: flex;
  flex-wrap: wrap;
}

.color-cell {
  width: 60rpx;
  height: 60rpx;
  margin: 0 16rpx 12rpx 0;
  border: 4rpx solid transparent;
  border-radius: 50%;

  &--active {
    border-color: var(--color-text);
  }
}
</style>
