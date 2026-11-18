<script setup lang="ts">
import {
  getCurrentInstance,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue'
import uCharts from '@qiun/ucharts'

import { formatYuan } from '@/utils/money'

type ChartType = 'ring' | 'pie' | 'column' | 'line'

interface ChartSeries {
  name?: string
  data: unknown[]
  color?: string
  [key: string]: unknown
}

interface ChartPayload {
  categories?: string[]
  series: ChartSeries[]
}

const props = defineProps<{
  canvasId: string
  chartType: ChartType
  chartData: ChartPayload
  height: number
  ringTitle?: string
  ringSubtitle?: string
}>()

const CATEGORY_COLORS = [
  '#8B93F2',
  '#B4A0E8',
  '#E7A0B8',
  '#7EB6E6',
  '#E7C07A',
  '#7EC8B8',
  '#F0B08A',
  '#A8B4E8',
]

const FONT_COLOR = '#8b8ba3'

const instance = getCurrentInstance()
const canvasWidth = ref(0)

let chart: any = null
let disposed = false

function fallbackWidth(): number {
  const info = uni.getSystemInfoSync()
  return Math.max(240, info.windowWidth - uni.upx2px(160))
}

function measureWidth(): Promise<number> {
  return new Promise((resolve) => {
    uni
      .createSelectorQuery()
      .in(instance?.proxy as never)
      .select('.chart')
      .boundingClientRect((rect) => {
        const box = rect as { width?: number } | null
        const width = box && box.width ? Number(box.width) : 0
        resolve(width > 0 ? width : fallbackWidth())
      })
      .exec()
  })
}

function compactAmount(value: number): string {
  if (value >= 10000) {
    return `${(value / 10000).toFixed(1)}w`
  }
  if (value >= 1000) {
    return `${(value / 1000).toFixed(1)}k`
  }
  return String(Math.round(value))
}

function tooltipOption(): Record<string, unknown> {
  return {
    showBox: true,
    showArrow: false,
    borderWidth: 1,
    borderColor: '#e4e6f0',
    borderRadius: 6,
    bgColor: '#ffffff',
    bgOpacity: 0.96,
    fontColor: '#1a1a2e',
    fontSize: 12,
    legendShow: true,
    legendShape: 'circle',
  }
}

function axisOption(labelCount: number): Record<string, unknown> {
  return {
    disableGrid: true,
    fontSize: 10,
    fontColor: FONT_COLOR,
    labelCount,
    marginTop: 8,
  }
}

function yAxisOption(): Record<string, unknown> {
  return {
    gridType: 'dash',
    dashLength: 4,
    splitNumber: 4,
    fontSize: 10,
    fontColor: FONT_COLOR,
    data: [
      {
        min: 0,
        formatter: (value: number) => compactAmount(value),
      },
    ],
  }
}

function buildOptions(context: unknown): Record<string, unknown> {
  const width = canvasWidth.value
  const height = props.height
  const base: Record<string, unknown> = {
    context,
    width,
    height,
    pixelRatio: 1,
    animation: true,
    background: '#ffffff',
    color: CATEGORY_COLORS,
    padding: [8, 8, 8, 8],
    dataLabel: false,
    dataPointShape: false,
    legend: { show: false },
    enableScroll: false,
    fontColor: FONT_COLOR,
    extra: { tooltip: tooltipOption() },
  }

  const payload = props.chartData

  if (props.chartType === 'ring') {
    return {
      ...base,
      type: 'ring',
      series: payload.series,
      title: {
        name: props.ringTitle || '',
        fontSize: 16,
        color: '#1a1a2e',
      },
      subtitle: {
        name: props.ringSubtitle || '',
        fontSize: 11,
        color: FONT_COLOR,
      },
      extra: {
        ...(base.extra as Record<string, unknown>),
        ring: {
          ringWidth: 18,
          activeOpacity: 0.6,
          activeRadius: 8,
          offsetAngle: -90,
          labelWidth: 15,
          border: false,
        },
      },
    }
  }

  if (props.chartType === 'pie') {
    return {
      ...base,
      type: 'pie',
      series: payload.series,
      extra: {
        ...(base.extra as Record<string, unknown>),
        pie: {
          activeOpacity: 0.6,
          activeRadius: 6,
          offsetAngle: 0,
          labelWidth: 15,
          border: false,
        },
      },
    }
  }

  if (props.chartType === 'column') {
    const count = Math.max(payload.categories?.length || 0, 1)
    const barWidth = Math.max(12, Math.min(30, Math.round((width / count) * 0.38)))
    return {
      ...base,
      type: 'column',
      categories: payload.categories || [],
      series: payload.series.map((serie) => ({
        ...serie,
        formatter: (value: unknown) =>
          value && typeof value === 'object' && 'value' in value
            ? (value as { value: number }).value
            : value,
      })),
      xAxis: axisOption(payload.categories?.length ? Math.min(6, count) : 0),
      yAxis: yAxisOption(),
      extra: {
        ...(base.extra as Record<string, unknown>),
        column: {
          type: 'group',
          width: barWidth,
          barBorderRadius: [6, 6, 0, 0],
          activeBgColor: '#6366f1',
          activeBgOpacity: 0.08,
        },
      },
    }
  }

  return {
    ...base,
    type: 'line',
    categories: payload.categories || [],
    series: payload.series,
    xAxis: axisOption(payload.categories?.length && payload.categories.length > 8 ? 6 : 0),
    yAxis: yAxisOption(),
    extra: {
      ...(base.extra as Record<string, unknown>),
      line: {
        type: 'curve',
        width: 2,
        activeType: 'hollow',
        onShadow: false,
      },
    },
  }
}

function draw(): void {
  if (disposed || !canvasWidth.value) {
    return
  }
  if (!props.chartData.series.length) {
    return
  }
  if (chart && typeof chart.stopAnimation === 'function') {
    chart.stopAnimation()
  }
  chart = null
  const context = uni.createCanvasContext(
    props.canvasId,
    instance?.proxy as never,
  )
  chart = new uCharts(buildOptions(context))
}

async function setupChart(): Promise<void> {
  await nextTick()
  canvasWidth.value = await measureWidth()
  await nextTick()
  draw()
}

function handleTouch(event: unknown): void {
  if (!chart) {
    return
  }
  chart.showToolTip(event, {
    formatter: (item: { name?: string; data?: unknown }) => {
      const cents = Math.round(Number(item.data) * 100)
      return `${item.name || ''}: ¥${formatYuan(cents)}`
    },
  })
}

watch(
  () => props.chartData,
  () => {
    if (canvasWidth.value) {
      draw()
    }
  },
  { deep: true },
)

onMounted(() => {
  void setupChart()
})

onBeforeUnmount(() => {
  disposed = true
  if (chart && typeof chart.stopAnimation === 'function') {
    chart.stopAnimation()
  }
  chart = null
})
</script>

<template>
  <view class="chart">
    <canvas
      :id="canvasId"
      :canvas-id="canvasId"
      class="chart__canvas"
      :style="{ width: canvasWidth ? `${canvasWidth}px` : '100%', height: `${height}px` }"
      @touchend="handleTouch"
    />
  </view>
</template>

<style lang="scss" scoped>
.chart {
  width: 100%;

  &__canvas {
    display: block;
  }
}
</style>
