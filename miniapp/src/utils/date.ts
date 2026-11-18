function pad(value: number): string {
  return String(value).padStart(2, '0')
}

export function toISODate(date: Date): string {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

export function todayISO(): string {
  return toISODate(new Date())
}

export function parseISODate(iso: string): Date {
  const [year, month, day] = iso.slice(0, 10).split('-').map(Number)
  return new Date(year, (month || 1) - 1, day || 1)
}

export function dayLabel(iso: string): string {
  const date = parseISODate(iso)
  return `${date.getMonth() + 1}月${date.getDate()}日`
}

export function weekdayLabel(iso: string): string {
  const names = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
  return names[parseISODate(iso).getDay()]
}

export function addDaysISO(iso: string, days: number): string {
  const date = parseISODate(iso)
  date.setDate(date.getDate() + days)
  return toISODate(date)
}

export function startOfWeekISO(iso: string): string {
  const date = parseISODate(iso)
  const offset = (date.getDay() + 6) % 7
  date.setDate(date.getDate() - offset)
  return toISODate(date)
}

export function addMonths(
  year: number,
  month: number,
  delta: number,
): { year: number; month: number } {
  const index = year * 12 + (month - 1) + delta
  return { year: Math.floor(index / 12), month: (index % 12) + 1 }
}

export function rangeLabel(startISO: string, endISO: string): string {
  return `${dayLabel(startISO)} - ${dayLabel(endISO)}`
}
