/**
 * Generic localStorage helpers — not Apollo-specific. Kept as a leaf module
 * (zero imports) so reactive vars can use them at module-init time without
 * forming a `cacheUtils ↔ reactiveVars` import cycle through the Apollo
 * module graph.
 *
 * This file MUST NOT import from `@apollo/client`, `~/core/apolloClient`,
 * or anything that transitively pulls them in. That invariant is what makes
 * it safe to import from any reactive var.
 */
export const getItemFromLS = (key: string) => {
  const data = typeof window !== 'undefined' ? localStorage.getItem(key) : ''

  try {
    if (data === 'undefined') {
      return undefined
    }

    return !!data ? JSON.parse(data) : data
  } catch {
    return data
  }
}

export const setItemFromLS = (key: string, value: unknown) => {
  const stringify = typeof value !== 'string' ? JSON.stringify(value) : value

  return localStorage.setItem(key, stringify)
}

export const removeItemFromLS = (key: string) => {
  return localStorage.removeItem(key)
}
