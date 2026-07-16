import { RefObject, useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'

export const GROUP_NAMES = ['undoRedo', 'textStyling', 'lists', 'alignment', 'media'] as const

export type GroupName = (typeof GROUP_NAMES)[number]

type UseToolbarOverflowParams = {
  containerRef: RefObject<HTMLDivElement | null>
  groupRefs: Record<GroupName, RefObject<HTMLDivElement | null>>
  kebabRef: RefObject<HTMLDivElement | null>
  gap: number // gap in px between flex children (Tailwind gap-2 = 8px)
  separatorWidth: number // width of separator between groups (w-px = 1px)
}

type UseToolbarOverflowReturn = {
  visibleGroups: Set<GroupName>
  overflowedGroups: GroupName[]
  hasOverflow: boolean
}

export const useToolbarOverflow = ({
  containerRef,
  groupRefs,
  kebabRef,
  gap,
  separatorWidth,
}: UseToolbarOverflowParams): UseToolbarOverflowReturn => {
  const [visibleGroups, setVisibleGroups] = useState<Set<GroupName>>(new Set(GROUP_NAMES))
  const rafId = useRef<number>(0)
  const widthCache = useRef<Map<GroupName, number>>(new Map())

  const calculate = useCallback(() => {
    const container = containerRef.current

    if (!container) return

    const containerStyles = getComputedStyle(container)
    const containerWidth =
      container.clientWidth -
      Number.parseFloat(containerStyles.paddingLeft) -
      Number.parseFloat(containerStyles.paddingRight)
    const kebabWidth = kebabRef.current?.scrollWidth ?? 0

    // Measure all visible groups first so the cache is fully populated
    // before the fitting loop. This prevents groups after a `break` from
    // being permanently skipped when they were never reached on initial calc.
    for (const name of GROUP_NAMES) {
      const el = groupRefs[name].current

      if (el) {
        widthCache.current.set(name, el.scrollWidth)
      }
    }

    let usedWidth = 0
    const newVisible = new Set<GroupName>()

    for (const name of GROUP_NAMES) {
      const groupWidth = widthCache.current.get(name)

      if (groupWidth === undefined) continue // never measured, skip

      // Between groups: gap + separator(1px) + gap. No separator before first group.
      const groupSpacing = newVisible.size > 0 ? gap + separatorWidth + gap : 0
      // Reserve space for kebab + its gap (no separator before kebab)
      const remainingGroups = GROUP_NAMES.length - newVisible.size - 1
      const kebabReserve = remainingGroups > 0 ? kebabWidth + gap : 0

      if (usedWidth + groupSpacing + groupWidth + kebabReserve > containerWidth) {
        break
      }

      usedWidth += groupSpacing + groupWidth
      newVisible.add(name)
    }

    setVisibleGroups((prev) => {
      // Avoid unnecessary re-renders if the sets are identical
      if (prev.size === newVisible.size && Array.from(prev).every((g) => newVisible.has(g))) {
        return prev
      }

      return newVisible
    })
  }, [containerRef, groupRefs, kebabRef, gap, separatorWidth])

  useEffect(() => {
    const container = containerRef.current

    if (!container) return

    const observer = new ResizeObserver(() => {
      cancelAnimationFrame(rafId.current)
      rafId.current = requestAnimationFrame(calculate)
    })

    observer.observe(container)

    // Initial calculation
    calculate()

    return () => {
      observer.disconnect()
      cancelAnimationFrame(rafId.current)
    }
  }, [containerRef, calculate])

  // Recalculate after DOM updates (e.g., when kebab button mounts/unmounts).
  // The ResizeObserver won't fire for content changes if the container size is unchanged.
  useLayoutEffect(() => {
    calculate()
  }, [visibleGroups, calculate])

  const overflowedGroups = GROUP_NAMES.filter((name) => !visibleGroups.has(name))

  return {
    visibleGroups,
    overflowedGroups,
    hasOverflow: overflowedGroups.length > 0,
  }
}
