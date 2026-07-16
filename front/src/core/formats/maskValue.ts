export type MaskOptions = {
  /** Number of dots to prepend (default: 4) */
  dotsCount?: number
  /** Number of characters to show from the end. If not provided, shows the full value */
  visibleChars?: number
  /** Add space between dots and value (default: false) */
  withSpace?: boolean
}

/**
 * Masks a value by prepending dots.
 *
 * @example
 * maskValue('4242') // '••••4242'
 * maskValue('4242', { withSpace: true }) // '•••• 4242'
 * maskValue('abc123xyz', { visibleChars: 4 }) // '••••3xyz'
 */
export const maskValue = (value: string, options: MaskOptions = {}) => {
  if (!value) return '-'

  const { dotsCount = 4, visibleChars, withSpace = false } = options
  const displayValue = visibleChars ? value.slice(-visibleChars) : value
  const separator = withSpace ? ' ' : ''

  return `${'•'.repeat(dotsCount)}${separator}${displayValue}`
}
