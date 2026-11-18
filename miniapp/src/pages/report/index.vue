<script setup lang="ts">
import { computed, ref } from 'vue'
import { onPullDownRefresh, onShow } from '@dcloudio/uni-app'

import ChartCanvas from '@/components/chart-canvas.vue'
import EmptyState from '@/components/empty-state.vue'
import {
  fetchCategoryReport,
  fetchTrend,
  saveBudget,
  type ReportQuery,
} from '@/api/report'
import type {
  CategoryReport,
  CategoryReportItem,
  ReportPeriod,
  TrendReport,
} from '@/models/types'
import { setBillsFilter } from '@/stores/bills-filter'
import { hexToRgba } from '@/utils/color'
import {
  addDaysISO,
  addMonths,
  parseISODate,
  startOfWeekISO,
  todayISO,
} from '@/utils/date'
import { errorMessage } from '@/utils/error'
import {
  centsFromYuan,
  formatYuan,
  formatYuanInput,
} from '@/utils/money'

const SOFT_INCOME = '#7bc99a'
const SOFT_EXPENSE = '#e59898'
const INCOME_INK = '#2f7a52'
const EXPENSE_INK = '#c25555'

const CATEGORY_COLORS = [
  '#8b93f2',
  '#b4a0e8',
  '#e7a0b8',
  '#7eb6e6',
  '#e7c07a',
  '#7ec8b8',
  '#f0b08a',
  '#a8b4e8',
]

const now = new Date()
const period = ref<ReportPeriod>('month')
const year = ref(now.getFullYear())
const month = ref(now.getMonth() + 1)
const anchor = ref(todayISO())
const reportData = ref<CategoryReport | null>(null)
const trendData = ref<TrendReport | null>(null)
const loading = ref(true)
const loaded = ref(false)
const error = ref('')

const chartHeights = {
  ring: Math.round(uni.upx2px(360)),
  pie: Math.round(uni.upx2px(400)),
  column: Math.round(uni.upx2px(400)),
  line: Math.round(uni.upx2px(380)),
}

const periodOptions: { key: ReportPeriod; label: string }[] = [
  { key: 'week', label: '周' },
  { key: 'month', label: '月' },
  { key: 'year', label: '年' },
]

const weekStart = computed(() => startOfWeekISO(anchor.value))
const weekEnd = computed(() => addDaysISO(weekStart.value, 6))

const periodLabel = computed(() => {
  if (period.value === 'week') {
    const start = parseISODate(weekStart.value)
    const end = parseISODate(weekEnd.value)
    if (start.getFullYear() !== end.getFullYear()) {
      return `${start.getFullYear()}年${start.getMonth() + 1}月${start.getDate()}日 - ${end.getFullYear()}年${end.getMonth() + 1}月${end.getDate()}日`
    }
    if (start.getMonth() !== end.getMonth()) {
      return `${start.getFullYear()}年${start.getMonth() + 1}月${start.getDate()}日 - ${end.getMonth() + 1}月${end.getDate()}日`
    }
    return `${start.getFullYear()}年${start.getMonth() + 1}月${start.getDate()}日 - ${end.getDate()}日`
  }
  if (period.value === 'year') {
    return `${year.value}年`
  }
  return `${year.value}年${month.value}月`
})

const overviewTitle = computed(() => {
  if (period.value === 'week') return '周度概览'
  if (period.value === 'year') return '年度概览'
  return '月度概览'
})

const balanceLabel = computed(() => {
  if (period.value === 'week') return '周度结余'
  if (period.value === 'year') return '年度结余'
  return '月度结余'
})

const compareLabel = computed(() => {
  if (period.value === 'week') return '上周'
  if (period.value === 'year') return '上年'
  return '上月'
})

const budgetScopeLabel = computed(() => {
  if (period.value === 'week') return '本周'
  if (period.value === 'year') return '全年'
  return '本月'
})

const trendTitle = computed(() => {
  if (period.value === 'week') return '近 8 周'
  if (period.value === 'month') return '近 6 个月'
  return `${year.value}年各月`
})

const emptyText = computed(() => {
  if (period.value === 'week') return '该周暂无分类统计'
  if (period.value === 'year') return '该年暂无分类统计'
  return '该月暂无分类统计'
})

const chartEmptyHint = computed(() => {
  if (period.value === 'week') return '该周暂无收支数据'
  if (period.value === 'year') return '该年暂无收支数据'
  return '该月暂无收支数据'
})

const expenseRatio = computed(() => {
  const total =
    (reportData.value?.incomeCents ?? 0) + (reportData.value?.expenseCents ?? 0)
  if (total <= 0) return 0
  return (reportData.value?.expenseCents ?? 0) / total
})

const expenseItems = computed(() => {
  const items = reportData.value?.categories ?? []
  return items
    .filter((item) => item.expenseCents > 0)
    .sort((a, b) => b.expenseCents - a.expenseCents)
})

const expenseTotalCents = computed(() =>
  expenseItems.value.reduce((sum, item) => sum + item.expenseCents, 0),
)

const barItems = computed(() => expenseItems.value.slice(0, 6))

const maxCategoryTotal = computed(() => {
  const items = reportData.value?.categories ?? []
  return items.reduce(
    (max, item) => Math.max(max, item.incomeCents + item.expenseCents),
    0,
  )
})

const ringChartData = computed(() => {
  const data = reportData.value
  if (!data) {
    return { series: [] }
  }
  return {
    series: [
      {
        data: [
          { name: '收入', value: data.incomeCents / 100, color: SOFT_INCOME },
          { name: '支出', value: data.expenseCents / 100, color: SOFT_EXPENSE },
        ],
      },
    ],
  }
})

const pieChartData = computed(() => ({
  series: [
    {
      data: expenseItems.value.map((item) => ({
        name: item.category.name,
        value: item.expenseCents / 100,
        color: categoryTone(item.category.id),
      })),
    },
  ],
}))

const columnChartData = computed(() => ({
  categories: barItems.value.map((item) => item.category.name.slice(0, 2)),
  series: [
    {
      name: '支出',
      data: barItems.value.map((item) => ({
        value: item.expenseCents / 100,
        color: categoryTone(item.category.id),
      })),
    },
  ],
}))

const lineChartData = computed(() => {
  const points = trendData.value?.points ?? []
  return {
    categories: points.map((point) => point.label),
    series: [
      {
        name: '收入',
        color: SOFT_INCOME,
        pointShape: 'circle',
        pointSize: 2,
        data: points.map((point) => point.incomeCents / 100),
      },
      {
        name: '支出',
        color: SOFT_EXPENSE,
        pointShape: 'circle',
        pointSize: 2,
        data: points.map((point) => point.expenseCents / 100),
      },
    ],
  }
})

const trendSummary = computed(() => {
  const trend = trendData.value
  if (!trend) return ''
  return `${deltaText('支出', trend.expenseDeltaCents)}，${deltaText('收入', trend.incomeDeltaCents)}`
})

function categoryTone(id: number): string {
  return CATEGORY_COLORS[Math.abs(id) % CATEGORY_COLORS.length]
}

function deltaText(label: string, deltaCents: number): string {
  if (deltaCents === 0) {
    return `${label}与${compareLabel.value}持平`
  }
  const direction = deltaCents > 0 ? '多' : '少'
  return `比${compareLabel.value}${label}${direction} ¥${formatYuan(Math.abs(deltaCents))}`
}

function buildQuery(): ReportQuery {
  if (period.value === 'week') {
    return { period: 'week', anchor: weekStart.value }
  }
  if (period.value === 'year') {
    return { period: 'year', year: year.value }
  }
  return { period: 'month', year: year.value, month: month.value }
}

onShow(() => {
  void load()
})

onPullDownRefresh(async () => {
  await load()
  uni.stopPullDownRefresh()
})

async function load(): Promise<void> {
  if (!loaded.value) {
    loading.value = true
  }
  error.value = ''
  try {
    const query = buildQuery()
    const [nextReport, nextTrend] = await Promise.all([
      fetchCategoryReport(query),
      fetchTrend(query),
    ])
    reportData.value = nextReport
    trendData.value = nextTrend
    loaded.value = true
  } catch (err) {
    if (loaded.value) {
      uni.showToast({ title: errorMessage(err), icon: 'none' })
    } else {
      error.value = errorMessage(err)
    }
  } finally {
    loading.value = false
  }
}

function selectPeriod(next: ReportPeriod): void {
  if (period.value === next) {
    return
  }
  period.value = next
  void load()
}

function shiftPeriod(delta: number): void {
  if (period.value === 'week') {
    anchor.value = addDaysISO(anchor.value, delta * 7)
  } else if (period.value === 'year') {
    year.value += delta
  } else {
    const next = addMonths(year.value, month.value, delta)
    year.value = next.year
    month.value = next.month
  }
  void load()
}

function primaryAmount(item: CategoryReportItem): number {
  return item.expenseCents > 0 ? item.expenseCents : item.incomeCents
}

function hasBudget(item: CategoryReportItem): boolean {
  return item.budgetCents !== null && item.budgetCents > 0
}

function overBudget(item: CategoryReportItem): boolean {
  return hasBudget(item) && item.expenseCents > (item.budgetCents as number)
}

function barRatio(item: CategoryReportItem): number {
  if (hasBudget(item)) {
    return Math.min(1, item.expenseCents / (item.budgetCents as number))
  }
  if (maxCategoryTotal.value <= 0) {
    return 0
  }
  return Math.min(
    1,
    (item.incomeCents + item.expenseCents) / maxCategoryTotal.value,
  )
}

function budgetText(item: CategoryReportItem): string {
  if (!hasBudget(item)) {
    return '还没有预算'
  }
  const budget = item.budgetCents as number
  const remain = budget - item.expenseCents
  if (remain < 0) {
    return `超出 ¥${formatYuan(-remain)}`
  }
  return `${budgetScopeLabel.value}预算 ¥${formatYuan(budget)} · 还剩 ¥${formatYuan(remain)}`
}

function percentOf(cents: number): string {
  if (expenseTotalCents.value <= 0) {
    return '0%'
  }
  return `${Math.round((cents / expenseTotalCents.value) * 100)}%`
}

function openCategory(item: CategoryReportItem): void {
  const data = reportData.value
  if (!data) {
    return
  }
  setBillsFilter({
    period: period.value,
    start: data.start,
    end: data.end,
    categoryId: item.category.id,
    type: item.category.type,
  })
  uni.switchTab({ url: '/pages/bills/index' })
}

function editBudget(item: CategoryReportItem): void {
  const current = item.budgetCents
  const content = current && current > 0 ? formatYuanInput(current) : ''
  uni.showModal({
    title: `${item.category.name}预算`,
    content,
    editable: true,
    placeholderText: `${budgetScopeLabel.value}预算金额，留空表示清除`,
    confirmText: '保存',
    cancelText: '取消',
    success: (result) => {
      if (!result.confirm) {
        return
      }
      void submitBudget(item, result.content ?? '')
    },
  })
}

async function submitBudget(
  item: CategoryReportItem,
  raw: string,
): Promise<void> {
  const data = reportData.value
  if (!data) {
    return
  }
  const text = raw.trim()
  let amountCents = 0
  if (text) {
    const value = Number(text)
    if (!Number.isFinite(value) || value < 0) {
      uni.showToast({ title: '请输入有效金额', icon: 'none' })
      return
    }
    amountCents = centsFromYuan(value)
  }
  try {
    await saveBudget({
      categoryId: item.category.id,
      year: data.year,
      month: data.month,
      amountCents,
      scope: period.value,
      anchor: period.value === 'week' ? data.start : undefined,
    })
    uni.showToast({
      title: amountCents > 0 ? '预算已保存' : '预算已清除',
      icon: 'none',
    })
    await load()
  } catch (err) {
    uni.showToast({ title: errorMessage(err), icon: 'none' })
  }
}
</script>

<template>
  <view class="report">
    <view class="report__head">
      <text class="report__title">报告</text>
    </view>

    <view class="slider">
      <view
        v-for="item in periodOptions"
        :key="item.key"
        class="slider__item"
        :class="{ 'slider__item--active': period === item.key }"
        @tap="selectPeriod(item.key)"
      >
        <text
          class="slider__text"
          :class="{ 'slider__text--active': period === item.key }"
        >
          {{ item.label }}
        </text>
      </view>
    </view>

    <view class="period">
      <view class="period__nav" @tap="shiftPeriod(-1)">
        <text class="period__arrow">‹</text>
      </view>
      <text class="period__label">{{ periodLabel }}</text>
      <view class="period__nav" @tap="shiftPeriod(1)">
        <text class="period__arrow">›</text>
      </view>
    </view>

    <view v-if="loading" class="state">
      <text class="state__text">加载中…</text>
    </view>

    <view v-else-if="error" class="state">
      <text class="state__text">{{ error }}</text>
      <view class="state__btn" @tap="load">
        <text class="state__btn-text">重试</text>
      </view>
    </view>

    <template v-else-if="reportData">
      <view class="card">
        <text class="card__title">{{ overviewTitle }}</text>
        <view class="overview">
          <view class="overview__item">
            <text class="overview__label">收入</text>
            <text class="overview__value overview__value--income">
              ¥{{ formatYuan(reportData.incomeCents) }}
            </text>
          </view>
          <view class="overview__item">
            <text class="overview__label">支出</text>
            <text class="overview__value overview__value--expense">
              ¥{{ formatYuan(reportData.expenseCents) }}
            </text>
          </view>
          <view class="overview__item">
            <text class="overview__label">结余</text>
            <text
              class="overview__value"
              :class="
                reportData.totalCents >= 0
                  ? 'overview__value--income'
                  : 'overview__value--expense'
              "
            >
              ¥{{ formatYuan(reportData.totalCents) }}
            </text>
          </view>
        </view>
        <view class="ratio">
          <view class="ratio__track">
            <view
              class="ratio__fill"
              :style="{ width: `${Math.min(1, expenseRatio) * 100}%` }"
            />
          </view>
          <text class="ratio__label">
            支出占比 {{ (expenseRatio * 100).toFixed(1) }}%
          </text>
        </view>
      </view>

      <view class="card">
        <view class="card__head">
          <text class="card__title">{{ trendTitle }}</text>
        </view>
        <text class="card__desc">{{ trendSummary }}</text>
        <ChartCanvas
          v-if="trendData && trendData.points.length"
          canvas-id="trend-chart"
          chart-type="line"
          :chart-data="lineChartData"
          :height="chartHeights.line"
        />
        <text v-else class="card__empty">{{ chartEmptyHint }}</text>
      </view>

      <view class="card">
        <view class="card__head">
          <text class="card__title">收支结构</text>
          <text
            class="card__extra"
            :class="
              reportData.totalCents >= 0 ? 'card__extra--income' : 'card__extra--expense'
            "
          >
            结余 ¥{{ formatYuan(reportData.totalCents) }}
          </text>
        </view>
        <ChartCanvas
          v-if="reportData.incomeCents + reportData.expenseCents > 0"
          canvas-id="ring-chart"
          chart-type="ring"
          :chart-data="ringChartData"
          :height="chartHeights.ring"
          :ring-title="`${(expenseRatio * 100).toFixed(0)}%`"
          ring-subtitle="支出占比"
        />
        <text v-else class="card__empty">{{ chartEmptyHint }}</text>
        <view v-if="reportData.incomeCents + reportData.expenseCents > 0" class="legend-row">
          <view class="legend-row__item">
            <view class="legend-row__dot" :style="{ backgroundColor: SOFT_INCOME }" />
            <text class="legend-row__label">收入</text>
            <text class="legend-row__value">¥{{ formatYuan(reportData.incomeCents) }}</text>
          </view>
          <view class="legend-row__item">
            <view class="legend-row__dot" :style="{ backgroundColor: SOFT_EXPENSE }" />
            <text class="legend-row__label">支出</text>
            <text class="legend-row__value">¥{{ formatYuan(reportData.expenseCents) }}</text>
          </view>
        </view>
      </view>

      <view class="card">
        <text class="card__title">支出分类占比</text>
        <template v-if="expenseItems.length">
          <ChartCanvas
            canvas-id="pie-chart"
            chart-type="pie"
            :chart-data="pieChartData"
            :height="chartHeights.pie"
          />
          <view class="legend">
            <view
              v-for="item in expenseItems"
              :key="item.category.id"
              class="legend__item"
            >
              <view
                class="legend__icon"
                :style="{ backgroundColor: hexToRgba(categoryTone(item.category.id), 0.18) }"
              >
                <text class="legend__emoji">{{ item.category.icon }}</text>
              </view>
              <view class="legend__text">
                <text class="legend__name">{{ item.category.name }}</text>
                <text class="legend__value">
                  ¥{{ formatYuan(item.expenseCents) }} · {{ percentOf(item.expenseCents) }}
                </text>
              </view>
            </view>
          </view>
        </template>
        <text v-else class="card__empty">暂无支出分类数据</text>
      </view>

      <view class="card">
        <text class="card__title">分类支出对比</text>
        <ChartCanvas
          v-if="barItems.length"
          canvas-id="column-chart"
          chart-type="column"
          :chart-data="columnChartData"
          :height="chartHeights.column"
        />
        <text v-else class="card__empty">暂无支出分类数据</text>
      </view>

      <view class="section">
        <text class="section__title">分类统计</text>
      </view>

      <EmptyState v-if="!reportData.categories.length" :text="emptyText" />

      <view
        v-for="item in reportData.categories"
        :key="item.category.id"
        class="cat"
        @tap="openCategory(item)"
      >
        <view class="cat__row">
          <view
            class="cat__icon"
            :style="{ backgroundColor: hexToRgba(categoryTone(item.category.id), 0.18) }"
          >
            <text class="cat__emoji">{{ item.category.icon }}</text>
          </view>
          <view class="cat__info">
            <text class="cat__name">{{ item.category.name }}</text>
            <text class="cat__count">{{ item.transactionCount }} 笔</text>
          </view>
          <text
            class="cat__amount"
            :class="
              item.expenseCents > 0 ? 'cat__amount--expense' : 'cat__amount--income'
            "
          >
            ¥{{ formatYuan(primaryAmount(item)) }}
          </text>
        </view>
        <view class="cat__track">
          <view
            class="cat__fill"
            :style="{
              width: `${barRatio(item) * 100}%`,
              backgroundColor: overBudget(item)
                ? '#dc2626'
                : categoryTone(item.category.id),
            }"
          />
        </view>
        <view class="cat__footer">
          <text
            class="cat__budget"
            :class="{ 'cat__budget--over': overBudget(item) }"
          >
            {{ budgetText(item) }}
          </text>
          <view
            v-if="item.category.type === 'expense'"
            class="cat__budget-btn"
            @tap.stop="editBudget(item)"
          >
            <text class="cat__budget-btn-text">
              {{ hasBudget(item) ? '改预算' : '设预算' }}
            </text>
          </view>
        </view>
      </view>
    </template>

    <view class="report__bottom" />
  </view>
</template>

<style lang="scss" scoped>
.report {
  min-height: 100vh;
  padding-top: 24rpx;

  &__head {
    padding: 0 40rpx;
  }

  &__title {
    font-size: 44rpx;
    font-weight: 700;
    color: var(--color-text);
  }

  &__bottom {
    height: calc(48rpx + env(safe-area-inset-bottom));
  }
}

.slider {
  display: flex;
  margin: 24rpx 40rpx 8rpx;
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

.period {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 8rpx 40rpx 16rpx;

  &__nav {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 56rpx;
    height: 56rpx;
  }

  &__arrow {
    font-size: 40rpx;
    line-height: 1;
    color: var(--color-text-secondary);
  }

  &__label {
    min-width: 320rpx;
    font-size: 30rpx;
    font-weight: 600;
    color: var(--color-text);
    text-align: center;
  }
}

.card {
  margin: 0 40rpx 24rpx;
  padding: 32rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);

  &__head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 12rpx;
  }

  &__title {
    font-size: 28rpx;
    font-weight: 600;
    color: var(--color-text-secondary);
  }

  &__desc {
    display: block;
    margin-top: 8rpx;
    font-size: 24rpx;
    color: var(--color-text);
  }

  &__extra {
    font-size: 24rpx;
    font-weight: 600;

    &--income {
      color: #2f7a52;
    }

    &--expense {
      color: #c25555;
    }
  }

  &__empty {
    display: block;
    padding: 48rpx 0;
    font-size: 26rpx;
    color: var(--color-text-tertiary);
    text-align: center;
  }
}

.overview {
  display: flex;
  margin-top: 24rpx;

  &__item {
    display: flex;
    flex: 1;
    flex-direction: column;
  }

  &__label {
    font-size: 22rpx;
    color: var(--color-text-tertiary);
  }

  &__value {
    margin-top: 8rpx;
    font-size: 30rpx;
    font-weight: 700;
    color: var(--color-text);

    &--income {
      color: #2f7a52;
    }

    &--expense {
      color: #c25555;
    }
  }
}

.ratio {
  margin-top: 24rpx;

  &__track {
    height: 12rpx;
    background-color: rgba(123, 201, 154, 0.45);
    border-radius: 999rpx;
    overflow: hidden;
  }

  &__fill {
    height: 100%;
    background-color: #e59898;
    border-radius: 999rpx;
  }

  &__label {
    display: block;
    margin-top: 10rpx;
    font-size: 22rpx;
    color: var(--color-text-tertiary);
  }
}

.legend-row {
  display: flex;
  justify-content: space-around;
  margin-top: 8rpx;

  &__item {
    display: flex;
    align-items: center;
  }

  &__dot {
    width: 16rpx;
    height: 16rpx;
    margin-right: 10rpx;
    border-radius: 50%;
  }

  &__label {
    margin-right: 10rpx;
    font-size: 22rpx;
    color: var(--color-text-secondary);
  }

  &__value {
    font-size: 24rpx;
    font-weight: 600;
    color: var(--color-text);
  }
}

.legend {
  display: flex;
  flex-wrap: wrap;

  &__item {
    display: flex;
    align-items: center;
    box-sizing: border-box;
    width: 50%;
    margin-top: 20rpx;
    padding-right: 12rpx;
  }

  &__icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 56rpx;
    height: 56rpx;
    margin-right: 12rpx;
    border-radius: 16rpx;
  }

  &__emoji {
    font-size: 28rpx;
  }

  &__text {
    display: flex;
    flex: 1;
    flex-direction: column;
  }

  &__name {
    font-size: 24rpx;
    font-weight: 600;
    color: var(--color-text);
  }

  &__value {
    margin-top: 4rpx;
    font-size: 20rpx;
    color: var(--color-text-tertiary);
  }
}

.section {
  padding: 12rpx 40rpx;

  &__title {
    font-size: 28rpx;
    font-weight: 600;
    color: var(--color-text-secondary);
  }
}

.cat {
  margin: 0 40rpx 20rpx;
  padding: 28rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);

  &__row {
    display: flex;
    align-items: center;
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
    font-size: 36rpx;
  }

  &__info {
    display: flex;
    flex: 1;
    flex-direction: column;
  }

  &__name {
    font-size: 28rpx;
    font-weight: 600;
    color: var(--color-text);
  }

  &__count {
    margin-top: 4rpx;
    font-size: 22rpx;
    color: var(--color-text-tertiary);
  }

  &__amount {
    font-size: 28rpx;
    font-weight: 700;

    &--income {
      color: #2f7a52;
    }

    &--expense {
      color: #c25555;
    }
  }

  &__track {
    height: 10rpx;
    margin-top: 20rpx;
    background-color: rgba(228, 230, 240, 0.6);
    border-radius: 999rpx;
    overflow: hidden;
  }

  &__fill {
    height: 100%;
    border-radius: 999rpx;
  }

  &__footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: 14rpx;
  }

  &__budget {
    flex: 1;
    font-size: 22rpx;
    color: var(--color-text-tertiary);

    &--over {
      color: var(--color-expense);
    }
  }

  &__budget-btn {
    padding: 8rpx 24rpx;
    background-color: var(--color-primary-soft);
    border-radius: 999rpx;
  }

  &__budget-btn-text {
    font-size: 22rpx;
    font-weight: 600;
    color: var(--color-primary-deep);
  }
}

.state {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 96rpx 40rpx;

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
