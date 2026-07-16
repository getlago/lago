const SAFE_STRING_RE = /^[a-zA-Z_][a-zA-Z0-9_.-]*$/
const RISON_KEYWORDS = new Set(['!t', '!f', '!n'])

export function encodeRison(value: unknown): string {
  if (value === null) return '!n'
  if (value === undefined) return '!n'

  switch (typeof value) {
    case 'boolean':
      return value ? '!t' : '!f'
    case 'number':
      return String(value)
    case 'string':
      if (value === '') return "''"
      if (SAFE_STRING_RE.test(value) && !RISON_KEYWORDS.has(value)) return value
      return "'" + value.replace(/!/g, '!!').replace(/'/g, "!'") + "'"
    case 'object':
      if (Array.isArray(value)) {
        return '!(' + value.map(encodeRison).join(',') + ')'
      }
      return (
        '(' +
        Object.entries(value as Record<string, unknown>)
          .map(([k, v]) => k + ':' + encodeRison(v))
          .join(',') +
        ')'
      )
    default:
      return "''"
  }
}
