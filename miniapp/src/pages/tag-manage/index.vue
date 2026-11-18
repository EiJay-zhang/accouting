<script setup lang="ts">
import { computed, ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'

import EmptyState from '@/components/empty-state.vue'
import {
  createTag,
  deleteTag,
  fetchCategories,
  fetchTags,
  updateTag,
} from '@/api/transaction'
import type { Category, CategoryTag } from '@/models/types'
import { showConfirm } from '@/utils/confirm'
import { errorMessage } from '@/utils/error'

const categories = ref<Category[]>([])
const selectedId = ref(0)
const tags = ref<CategoryTag[]>([])
const loading = ref(true)

const selectedCategory = computed(() =>
  categories.value.find((item) => item.id === selectedId.value),
)

onShow(() => {
  void init()
})

async function init(): Promise<void> {
  try {
    if (!categories.value.length) {
      categories.value = await fetchCategories()
      if (!selectedId.value && categories.value.length) {
        selectedId.value = categories.value[0].id
      }
    }
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  }
  await loadTags()
}

async function loadTags(): Promise<void> {
  if (!selectedId.value) {
    loading.value = false
    return
  }
  loading.value = true
  try {
    tags.value = await fetchTags(selectedId.value)
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  } finally {
    loading.value = false
  }
}

function selectCategory(id: number): void {
  if (selectedId.value === id) {
    return
  }
  selectedId.value = id
  void loadTags()
}

function promptName(title: string, value: string): Promise<string | null> {
  return new Promise((resolve) => {
    uni.showModal({
      title,
      content: value,
      editable: true,
      placeholderText: '标签名称，最多 20 字',
      confirmText: '保存',
      cancelText: '取消',
      success: (result) => {
        resolve(result.confirm ? (result.content || '') : null)
      },
      fail: () => resolve(null),
    })
  })
}

async function addTag(): Promise<void> {
  if (!selectedId.value) {
    uni.showToast({ title: '请先选择分类', icon: 'none' })
    return
  }
  const name = await promptName(`新增标签 · ${selectedCategory.value?.name || ''}`, '')
  if (name === null) {
    return
  }
  if (!name.trim()) {
    uni.showToast({ title: '请填写标签名称', icon: 'none' })
    return
  }
  try {
    await createTag(selectedId.value, name.trim())
    await loadTags()
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  }
}

async function renameTag(tag: CategoryTag): Promise<void> {
  const name = await promptName('重命名标签', tag.name)
  if (name === null) {
    return
  }
  if (!name.trim()) {
    uni.showToast({ title: '请填写标签名称', icon: 'none' })
    return
  }
  try {
    await updateTag(tag.id, name.trim())
    await loadTags()
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  }
}

async function removeTag(tag: CategoryTag): Promise<void> {
  const confirmed = await showConfirm(
    `删除标签「${tag.name}」`,
    '账单上已使用的标签会一并移除。',
    '删除',
  )
  if (!confirmed) {
    return
  }
  try {
    await deleteTag(tag.id)
    await loadTags()
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  }
}
</script>

<template>
  <view class="page">
    <scroll-view class="cats" scroll-x :show-scrollbar="false">
      <view class="cats__inner">
        <view
          v-for="category in categories"
          :key="category.id"
          class="cats__chip"
          :class="{ 'cats__chip--active': category.id === selectedId }"
          @tap="selectCategory(category.id)"
        >
          <text
            class="cats__text"
            :class="{ 'cats__text--active': category.id === selectedId }"
          >
            {{ category.icon }} {{ category.name }}
          </text>
        </view>
      </view>
    </scroll-view>

    <view class="head">
      <text class="head__title">标签</text>
      <view class="head__add" @tap="addTag">
        <text class="head__add-text">＋ 新增</text>
      </view>
    </view>

    <view v-if="loading" class="state">
      <text class="state__text">加载中…</text>
    </view>

    <view v-else-if="tags.length" class="tags">
      <view
        v-for="tag in tags"
        :key="tag.id"
        class="tag"
        @tap="renameTag(tag)"
      >
        <text class="tag__name">{{ tag.name }}</text>
        <view class="tag__remove" @tap.stop="removeTag(tag)">
          <text class="tag__remove-text">×</text>
        </view>
      </view>
    </view>

    <EmptyState
      v-else
      text="该分类还没有标签"
      hint="标签会记在账单上，方便搜索和筛选"
    />

    <text class="page__hint">点击标签可重命名，点右侧 × 可删除。</text>
    <view class="page__bottom" />
  </view>
</template>

<style lang="scss" scoped>
.page {
  min-height: 100vh;
  padding: 24rpx 0 0;

  &__hint {
    display: block;
    margin: 28rpx 40rpx 0;
    font-size: 22rpx;
    color: var(--color-text-tertiary);
    text-align: center;
  }

  &__bottom {
    height: calc(60rpx + env(safe-area-inset-bottom));
  }
}

.cats {
  width: 100%;
  white-space: nowrap;

  &__inner {
    padding: 0 40rpx;
    white-space: nowrap;
  }

  &__chip {
    display: inline-block;
    margin-right: 16rpx;
    padding: 14rpx 28rpx;
    background-color: var(--color-surface);
    border-radius: 999rpx;

    &--active {
      background-color: var(--color-primary);
    }
  }

  &__text {
    font-size: 26rpx;
    color: var(--color-text-secondary);

    &--active {
      color: #ffffff;
      font-weight: 600;
    }
  }
}

.head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 32rpx 40rpx 16rpx;

  &__title {
    font-size: 28rpx;
    font-weight: 600;
    color: var(--color-text-secondary);
  }

  &__add {
    padding: 4rpx 8rpx;
  }

  &__add-text {
    font-size: 26rpx;
    font-weight: 600;
    color: var(--color-primary);
  }
}

.tags {
  display: flex;
  flex-wrap: wrap;
  margin: 0 40rpx;
  padding: 24rpx 24rpx 8rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);
}

.tag {
  display: flex;
  align-items: center;
  margin: 0 16rpx 16rpx 0;
  padding: 14rpx 12rpx 14rpx 24rpx;
  background-color: var(--color-surface-muted);
  border-radius: 999rpx;

  &__name {
    font-size: 26rpx;
    color: var(--color-text);
  }

  &__remove {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 40rpx;
    height: 40rpx;
    margin-left: 6rpx;
    border-radius: 50%;
  }

  &__remove-text {
    font-size: 28rpx;
    line-height: 1;
    color: var(--color-text-tertiary);
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
</style>
