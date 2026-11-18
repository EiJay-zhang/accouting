export function centsFromYuan(value: string | number): number {
  return Math.round(Number(value) * 100)
}

export function formatYuan(cents: number): string {
  return (Number(cents) / 100).toFixed(2)
}
