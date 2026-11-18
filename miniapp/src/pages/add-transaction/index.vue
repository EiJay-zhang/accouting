<script setup lang="ts">
import { computed, ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'

import CategoryGrid from '@/components/category-grid.vue'
import MoneyInput from '@/components/money-input.vue'
import TagChips from '@/components/tag-chips.vue'
import {
  createTransaction,
  deleteTransaction,
  fetchCategories,
  fetchTags,
  updateTransaction,
} from '@/api/transaction'
import type {
  Category,
  CategoryTag,
  Transaction,
  TransactionType,
} from '@/models/types'
import { takePendingEdit } from '@/stores/transaction-edit'
import { showConfirm } from '@/utils/confirm'
import { parseISODate, todayISO } from '@/utils/date'
import { errorMessage } from '@/utils/error'
import { centsFromYuan, formatYuanInput } from '@/utils/money'

const editing = ref<Transaction | null>(null)
const type = ref<TransactionType>('expense')
const amountText = ref('')
const title = ref('')
const date = ref(todayISO())
const categoryId = ref<number | null>(null)
const selectedTagIds = ref<number[]>([])
const categories = ref<Category[]>([])
const tags = ref<CategoryTag[]>([])
const loading = ref(true)
const loadError = ref('')
const submitting = ref(false)

const typeOptions: { key: TransactionType; label: string }[] = [
  { key: 'expense', label: '支出' },
  { key: 'income', label: '收入' },
]

const visibleCategories = computed(() =>
  categories.value.filter((category) => category.type === type.value),
)

const visibleTags = computed(() =>
  tags.value.filter((tag) => tag.category_id === categoryId.value),
)

const dateLabel = computed(() => {
  const value = parseISODate(date.value)
  return `${value.getFullYear()}年${value.getMonth() + 1}月${value.getDate()}日`
})

onLoad(() => {
  const existing = takePendingEdit()
  if (existing) {
    editing.value = existing
    type.value = existing.type
    amountText.value = formatYuanInput(existing.amountCents)
    title.value = existing.title
    date.value = existing.date.slice(0, 10)
    categoryId.value = existing.category.id
    selectedTagIds.value = existing.tags.map((tag) => tag.id)
    uni.setNavigationBarTitle({ title: '编辑账单' })
  }
  void loadMeta()
})

async function loadMeta(): Promise<void> {
  loading.value = true
  loadError.value = ''
  try {
    const [nextCategories, nextTags] = await Promise.all([
      fetchCategories(),
      fetchTags(),
    ])
    categories.value = nextCategories
    tags.value = nextTags

    const preferred = categoryId.value
    if (
      preferred === null ||
      !nextCategories.some(
        (category) =>
          category.id === preferred && category.type === type.value,
      )
    ) {
      categoryId.value = visibleCategories.value[0]?.id ?? null
    }

    selectedTagIds.value = selectedTagIds.value.filter((id) =>
      nextTags.some(
        (tag) => tag.id === id && tag.category_id === categoryId.value,
      ),
    )
  } catch (err) {
    loadError.value = errorMessage(err)
  } finally {
    loading.value = false
  }
}

function selectType(next: TransactionType): void {
  if (next === type.value || submitting.value) {
    return
  }
  type.value = next
  categoryId.value = visibleCategories.value[0]?.id ?? null
  selectedTagIds.value = []
}

function selectCategory(value: number): void {
  categoryId.value = value
  selectedTagIds.value = selectedTagIds.value.filter((id) =>
    tags.value.some((tag) => tag.id === id && tag.category_id === value),
  )
}

function updateTagIds(next: number[]): void {
  const added = next.find((id) => !selectedTagIds.value.includes(id))
  if (added !== undefined) {
    const tag = tags.value.find((item) => item.id === added)
    if (tag && !title.value.trim()) {
      title.value = tag.name
    }
  }

  const removed = selectedTagIds.value.find((id) => !next.includes(id))
  if (removed !== undefined) {
    const tag = tags.value.find((item) => item.id === removed)
    if (tag && title.value === tag.name) {
      title.value = ''
    }
  }

  selectedTagIds.value = next
}

function onTitleInput(event: Event): void {
  const detail = (event as unknown as { detail: { value: string } }).detail
  title.value = detail.value
}

function onDateChange(event: { detail: { value: string } }): void {
  date.value = event.detail.value
}

function toast(message: string): void {
  uni.showToast({ title: message, icon: 'none' })
}

async function submit(): Promise<void> {
  if (submitting.value) {
    return
  }

  const cents = centsFromYuan(amountText.value)
  if (!amountText.value.trim() || !Number.isFinite(cents) || cents <= 0) {
    toast('请输入有效金额')
    return
  }

  const category = categories.value.find(
    (item) => item.id === categoryId.value,
  )
  if (!category) {
    toast('请选择分类')
    return
  }

  const payload = {
    title: title.value.trim() || category.name,
    category_id: category.id,
    amount: cents / 100,
    type: type.value,
    date: date.value,
    tag_ids: selectedTagIds.value,
  }

  submitting.value = true
  try {
    if (editing.value) {
      await updateTransaction(editing.value.id, payload)
    } else {
      await createTransaction(payload)
    }
    uni.showToast({ title: '已保存', icon: 'success', duration: 600 })
    setTimeout(() => {
      uni.navigateBack()
    }, 600)
  } catch (err) {
    toast(errorMessage(err))
  } finally {
    submitting.value = false
  }
}

async function handleDelete(): Promise<void> {
  const target = editing.value
  if (!target || submitting.value) {
    return
  }
  const confirmed = await showConfirm(
    '删除账单',
    `确定删除「${target.title}」吗？删除后不可恢复。`,
    '删除',
  )
  if (!confirmed) {
    return
  }

  submitting.value = true
  try {
    await deleteTransaction(target.id)
    uni.showToast({ title: '已删除', icon: 'none' })
    setTimeout(() => {
      uni.navigateBack()
    }, 400)
  } catch (err) {
    toast(errorMessage(err))
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <view class="page">
    <view v-if="loading" class="state">
      <text class="state__text">加载中…</text>
    </view>

    <view v-else-if="loadError" class="state">
      <text class="state__text">{{ loadError }}</text>
      <view class="state__btn" @tap="loadMeta">
        <text class="state__btn-text">重试</text>
      </view>
    </view>

    <template v-else>
      <view class="type-switch">
        <view
          v-for="option in typeOptions"
          :key="option.key"
          class="type-switch__item"
          :class="[
            type === option.key ? 'type-switch__item--active' : '',
            type === option.key
              ? option.key === 'expense'
                ? 'type-switch__item--expense'
                : 'type-switch__item--income'
              : '',
          ]"
          @tap="selectType(option.key)"
        >
          <text
            class="type-switch__text"
            :class="{
              'type-switch__text--expense':
                type === option.key && option.key === 'expense',
              'type-switch__text--income':
                type === option.key && option.key === 'income',
            }"
          >
            {{ option.label }}
          </text>
        </view>
      </view>

      <MoneyInput
        v-model="amountText"
        :type="type"
        :disabled="submitting"
      />

      <view class="field">
        <input
          class="field__input"
          type="text"
          :value="title"
          :disabled="submitting"
          placeholder="添加备注…"
          placeholder-style="color: #8b8ba3"
          @input="onTitleInput"
        />
      </view>

      <view v-if="visibleTags.length" class="block">
        <text class="block__title">标签</text>
        <TagChips
          :tags="visibleTags"
          :model-value="selectedTagIds"
          @update:model-value="updateTagIds"
        />
      </view>
      <view v-else-if="categoryId !== null" class="hint">
        <text class="hint__text">
          这个分类还没有标签，可在「我的 - 标签管理」中添加
        </text>
      </view>

      <picker
        mode="date"
        :value="date"
        start="2000-01-01"
        end="2100-12-31"
        @change="onDateChange"
      >
        <view class="field field--row">
          <text class="field__icon">📅</text>
          <text class="field__value">{{ dateLabel }}</text>
          <text class="field__arrow">›</text>
        </view>
      </picker>

      <view class="block">
        <text class="block__title">选择分类</text>
        <CategoryGrid
          v-if="visibleCategories.length"
          :categories="visibleCategories"
          :model-value="categoryId"
          @update:model-value="selectCategory"
        />
        <view v-else class="hint">
          <text class="hint__text">
            还没有{{ type === 'expense' ? '支出' : '收入' }}分类
          </text>
        </view>
      </view>

      <view class="save" @tap="submit">
        <text class="save__text">
          {{ submitting ? '保存中…' : editing ? '保存修改' : '保存' }}
        </text>
      </view>

      <view v-if="editing" class="delete" @tap="handleDelete">
        <text class="delete__text">删除账单</text>
      </view>
    </template>
  </view>
</template>

<style lang="scss" scoped>
.page {
  min-height: 100vh;
  padding: 32rpx 40rpx calc(64rpx + env(safe-area-inset-bottom));
}

.type-switch {
  display: flex;
  padding: 6rpx;
  background-color: var(--color-surface);
  border-radius: 20rpx;

  &__item {
    display: flex;
    flex: 1;
    align-items: center;
    justify-content: center;
    padding: 18rpx 0;
    border-radius: 16rpx;

    &--active {
      background-color: var(--color-primary-soft);
    }

    &--expense {
      background-color: rgba(220, 38, 38, 0.14);
    }

    &--income {
      background-color: rgba(22, 163, 74, 0.14);
    }
  }

  &__text {
    font-size: 30rpx;
    font-weight: 600;
    color: var(--color-text-tertiary);

    &--expense {
      color: var(--color-expense);
    }

    &--income {
      color: var(--color-income);
    }
  }
}

.field {
  display: flex;
  align-items: center;
  margin-top: 24rpx;
  padding: 0 28rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-control);

  &--row {
    padding-top: 26rpx;
    padding-bottom: 26rpx;
  }

  &__input {
    flex: 1;
    height: 88rpx;
    font-size: 30rpx;
    color: var(--color-text);
  }

  &__icon {
    margin-right: 16rpx;
    font-size: 30rpx;
  }

  &__value {
    flex: 1;
    font-size: 30rpx;
    color: var(--color-text);
  }

  &__arrow {
    font-size: 32rpx;
    color: var(--color-text-tertiary);
  }
}

.block {
  margin-top: 36rpx;

  &__title {
    display: block;
    margin-bottom: 20rpx;
    font-size: 28rpx;
    font-weight: 500;
    color: var(--color-text-secondary);
  }
}

.hint {
  margin-top: 24rpx;
  padding: 24rpx 28rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-control);

  &__text {
    font-size: 24rpx;
    color: var(--color-text-tertiary);
  }
}

.save {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100rpx;
  margin-top: 48rpx;
  background: linear-gradient(135deg, #6366f1 0%, #4338ca 100%);
  border-radius: var(--radius-control);
  box-shadow: 0 14rpx 32rpx rgba(67, 56, 202, 0.24);

  &__text {
    font-size: 30rpx;
    font-weight: 600;
    color: #ffffff;
  }
}

.delete {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 88rpx;
  margin-top: 24rpx;
  background-color: var(--color-surface);
  border: 2rpx solid var(--color-border);
  border-radius: var(--radius-control);

  &__text {
    font-size: 28rpx;
    color: var(--color-danger);
  }
}

.state {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 160rpx 40rpx;

  &__text {
    font-size: 28rpx;
    color: var(--color-text-secondary);
    text-align: center;
  }

  &__btn {
    margin-top: 32rpx;
    padding: 16rpx 56rpx;
    background-color: var(--color-primary);
    border-radius: 999rpx;
  }

  &__btn-text {
    font-size: 28rpx;
    font-weight: 600;
    color: #ffffff;
  }
}
</style>
