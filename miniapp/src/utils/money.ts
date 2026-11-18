export function centsFromYuan(value: string | number): number {
  return Math.round(Number(value) * 100)
}

export function formatYuan(cents: number): string {
  return (Number(cents) / 100).toFixed(2)
}

export function formatYuanInput(cents: number): string {
  if (cents % 100 === 0) {
    return String(cents / 100)
  }
  return formatYuan(cents)
}

export function formatSignedYuan(cents: number): string {
  if (cents === 0) {
    return '0.00'
  }
  const sign = cents > 0 ? '+' : '-'
  return `${sign}${formatYuan(Math.abs(cents))}`
}
