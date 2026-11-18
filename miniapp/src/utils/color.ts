export function hexToRgba(hex: string, alpha: number): string {
  const value = hex.replace('#', '')
  const full =
    value.length === 3
      ? value
          .split('')
          .map((char) => char + char)
          .join('')
      : value
  const red = parseInt(full.slice(0, 2), 16)
  const green = parseInt(full.slice(2, 4), 16)
  const blue = parseInt(full.slice(4, 6), 16)
  if ([red, green, blue].some((item) => Number.isNaN(item))) {
    return `rgba(99, 102, 241, ${alpha})`
  }
  return `rgba(${red}, ${green}, ${blue}, ${alpha})`
}
