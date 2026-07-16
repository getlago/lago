const SCROLLABLE_OVERFLOW = new Set(['auto', 'scroll', 'overlay'])

export const findNearestScrollableAncestor = (el: HTMLElement | null): HTMLElement | null => {
  if (!el) return null

  let current: HTMLElement | null = el.parentElement

  while (current && current !== document.body) {
    const { overflowY } = window.getComputedStyle(current)

    if (SCROLLABLE_OVERFLOW.has(overflowY)) return current
    current = current.parentElement
  }

  return document.scrollingElement as HTMLElement | null
}
