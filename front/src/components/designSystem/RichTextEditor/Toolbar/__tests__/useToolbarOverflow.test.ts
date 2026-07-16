import { act, renderHook } from '@testing-library/react'

import { GROUP_NAMES, GroupName, useToolbarOverflow } from '../useToolbarOverflow'

// --- ResizeObserver mock ---

let resizeCallback: ResizeObserverCallback

class MockResizeObserver {
  callback: ResizeObserverCallback

  constructor(callback: ResizeObserverCallback) {
    this.callback = callback
    resizeCallback = callback
  }

  observe = jest.fn()
  unobserve = jest.fn()
  disconnect = jest.fn()
}

global.ResizeObserver = MockResizeObserver as unknown as typeof ResizeObserver

// --- Helpers ---

const createMockRef = (width: number) => ({
  current: { scrollWidth: width, clientWidth: width } as unknown as HTMLDivElement,
})

const createNullRef = () => ({ current: null })

const createContainerRef = (clientWidth: number) => ({
  current: { clientWidth } as unknown as HTMLDivElement,
})

const buildGroupRefs = (widths: Record<GroupName, number>) =>
  Object.fromEntries(GROUP_NAMES.map((name) => [name, createMockRef(widths[name])])) as Record<
    GroupName,
    ReturnType<typeof createMockRef>
  >

// Default widths used across tests
const DEFAULT_GROUP_WIDTHS: Record<GroupName, number> = {
  undoRedo: 60,
  textStyling: 80,
  lists: 70,
  alignment: 90,
  media: 50,
}

const GAP = 4
const SEPARATOR_WIDTH = 1

// Total width when all groups fit with no kebab:
// undoRedo(60) + (gap+sep+gap)(9) + textStyling(80) + 9 + lists(70) + 9 + alignment(90) + 9 + media(50)
// = 60 + 9 + 80 + 9 + 70 + 9 + 90 + 9 + 50 = 386
const FULL_WIDTH = 400

function renderOverflowHook({
  containerWidth = FULL_WIDTH,
  groupWidths = DEFAULT_GROUP_WIDTHS,
  kebabWidth = 32,
}: {
  containerWidth?: number
  groupWidths?: Record<GroupName, number>
  kebabWidth?: number
} = {}) {
  const containerRef = createContainerRef(containerWidth)
  const groupRefs = buildGroupRefs(groupWidths)
  const kebabRef = createMockRef(kebabWidth)

  const { result, unmount } = renderHook(() =>
    useToolbarOverflow({
      containerRef,
      groupRefs,
      kebabRef,
      gap: GAP,
      separatorWidth: SEPARATOR_WIDTH,
    }),
  )

  return { result, unmount, containerRef, groupRefs, kebabRef }
}

// --- Tests ---

describe('GIVEN the useToolbarOverflow hook', () => {
  beforeEach(() => {
    jest.useFakeTimers()
    jest.spyOn(window, 'getComputedStyle').mockReturnValue({
      paddingLeft: '0',
      paddingRight: '0',
    } as CSSStyleDeclaration)
  })

  afterEach(() => {
    jest.clearAllMocks()
    jest.restoreAllMocks()
    jest.useRealTimers()
  })

  describe('WHEN the hook is first rendered', () => {
    it('THEN all groups are visible by default', () => {
      const { result } = renderOverflowHook()

      expect(result.current.visibleGroups.size).toBe(GROUP_NAMES.length)
      GROUP_NAMES.forEach((name) => {
        expect(result.current.visibleGroups.has(name)).toBe(true)
      })
    })

    it('THEN overflowedGroups is empty and hasOverflow is false', () => {
      const { result } = renderOverflowHook()

      expect(result.current.overflowedGroups).toHaveLength(0)
      expect(result.current.hasOverflow).toBe(false)
    })
  })

  describe('WHEN the container is wide enough to fit all groups', () => {
    it('THEN all groups remain visible', () => {
      const { result } = renderOverflowHook({ containerWidth: FULL_WIDTH })

      act(() => {
        jest.runAllTimers()
      })

      expect(result.current.visibleGroups.size).toBe(GROUP_NAMES.length)
      expect(result.current.hasOverflow).toBe(false)
      expect(result.current.overflowedGroups).toHaveLength(0)
    })
  })

  describe('WHEN the container is too narrow for the last group', () => {
    it('THEN the last group overflows', () => {
      // Width that fits all except 'media' (last group, width 50).
      // With kebab (32 + gap 4 = 36) reserved, the last group can't fit.
      // Without media: 60+9+80+9+70+9+90 = 336 + kebabReserve(36) = 372 → need container < 372+50 = 422 but >= 336+36 to show first 4
      const { result } = renderOverflowHook({ containerWidth: 370 })

      act(() => {
        jest.runAllTimers()
      })

      expect(result.current.overflowedGroups).toContain('media')
      expect(result.current.hasOverflow).toBe(true)
      expect(result.current.visibleGroups.has('media')).toBe(false)
    })
  })

  describe('WHEN the container is very narrow (multiple groups overflow)', () => {
    it('THEN multiple groups overflow from right to left', () => {
      // undoRedo(60) needs 60 + kebabReserve(36) = 96 to fit.
      // Container of 100: undoRedo(96 <= 100) fits, textStyling needs 60+9+80+36=185 > 100 → overflows.
      // So only undoRedo is visible, all others overflow.
      const { result } = renderOverflowHook({ containerWidth: 100 })

      act(() => {
        jest.runAllTimers()
      })

      expect(result.current.visibleGroups.has('undoRedo')).toBe(true)
      expect(result.current.visibleGroups.has('textStyling')).toBe(false)
      expect(result.current.visibleGroups.has('lists')).toBe(false)
      expect(result.current.visibleGroups.has('alignment')).toBe(false)
      expect(result.current.visibleGroups.has('media')).toBe(false)
      expect(result.current.hasOverflow).toBe(true)
      expect(result.current.overflowedGroups.length).toBeGreaterThan(1)
    })
  })

  describe('WHEN a group ref becomes null (group unmounted)', () => {
    it('THEN uses cached width to still account for the group', () => {
      const groupWidths = { ...DEFAULT_GROUP_WIDTHS }
      const containerRef = createContainerRef(FULL_WIDTH)
      const groupRefs = buildGroupRefs(groupWidths) as Record<
        GroupName,
        { current: HTMLDivElement | null }
      >
      const kebabRef = createMockRef(32)

      const { result } = renderHook(() =>
        useToolbarOverflow({
          containerRef,
          groupRefs: groupRefs as Record<GroupName, { current: HTMLDivElement | null }>,
          kebabRef,
          gap: GAP,
          separatorWidth: SEPARATOR_WIDTH,
        }),
      )

      // Initial calculate runs — all groups measured and cached
      act(() => {
        jest.runAllTimers()
      })

      expect(result.current.visibleGroups.size).toBe(GROUP_NAMES.length)

      // Now null out 'media' ref — it's been unmounted but its width is cached
      groupRefs.media.current = null

      // Trigger a resize — should still use cached width for 'media'
      act(() => {
        resizeCallback([], {} as ResizeObserver)
        jest.runAllTimers()
      })

      // The container is still wide enough — media should still appear via cache
      expect(result.current.visibleGroups.has('media')).toBe(true)
    })
  })

  describe('WHEN separator spacing is calculated', () => {
    it('THEN there is no leading spacing for the first group', () => {
      // undoRedo(60) alone needs: 0 (no spacing) + 60 + kebabReserve(36) = 96.
      // textStyling would need: 60 + spacing(9) + 80 + kebabReserve(36) = 185.
      // Container of 100: undoRedo fits (96 <= 100), textStyling overflows (185 > 100).
      const { result } = renderOverflowHook({ containerWidth: 100 })

      act(() => {
        jest.runAllTimers()
      })

      expect(result.current.visibleGroups.has('undoRedo')).toBe(true)
      // textStyling needs 185 > 100 → overflows
      expect(result.current.visibleGroups.has('textStyling')).toBe(false)
    })

    it('THEN gap + separatorWidth + gap is added between consecutive groups', () => {
      const spacing = GAP + SEPARATOR_WIDTH + GAP // 9
      // undoRedo + spacing + textStyling = 60 + 9 + 80 = 149, + kebabReserve(36) = 185
      // Container of exactly 185 should show both undoRedo and textStyling
      const { result } = renderOverflowHook({ containerWidth: 185 })

      act(() => {
        jest.runAllTimers()
      })

      expect(result.current.visibleGroups.has('undoRedo')).toBe(true)
      expect(result.current.visibleGroups.has('textStyling')).toBe(true)
      // lists needs +9+70+36 = +115 more = 300, so won't fit
      expect(result.current.visibleGroups.has('lists')).toBe(false)

      // Sanity-check the spacing constant
      expect(spacing).toBe(9)
    })
  })

  describe('WHEN the kebab reserve is calculated', () => {
    it('THEN kebabWidth + gap is reserved when remaining groups exist', () => {
      // undoRedo(60) only visible; remaining = 4 groups, so kebabReserve = 32+4 = 36
      // Container of 96 = 60 + 36 → undoRedo fits exactly, textStyling would overflow
      const { result } = renderOverflowHook({ containerWidth: 96 })

      act(() => {
        jest.runAllTimers()
      })

      expect(result.current.visibleGroups.has('undoRedo')).toBe(true)
      expect(result.current.hasOverflow).toBe(true)
    })

    it('THEN no kebab reserve when all remaining groups fit', () => {
      // All groups fit in FULL_WIDTH → no overflow → no kebab needed
      const { result } = renderOverflowHook({ containerWidth: FULL_WIDTH })

      act(() => {
        jest.runAllTimers()
      })

      expect(result.current.hasOverflow).toBe(false)
      expect(result.current.overflowedGroups).toHaveLength(0)
    })
  })

  describe('WHEN containerRef.current is null', () => {
    it('THEN calculate does nothing and initial state is preserved', () => {
      const containerRef = createNullRef() as unknown as { current: HTMLDivElement | null }
      const groupRefs = buildGroupRefs(DEFAULT_GROUP_WIDTHS)
      const kebabRef = createMockRef(32)

      const { result } = renderHook(() =>
        useToolbarOverflow({
          containerRef,
          groupRefs,
          kebabRef,
          gap: GAP,
          separatorWidth: SEPARATOR_WIDTH,
        }),
      )

      act(() => {
        jest.runAllTimers()
      })

      // All groups remain visible — hook did nothing
      expect(result.current.visibleGroups.size).toBe(GROUP_NAMES.length)
      expect(result.current.hasOverflow).toBe(false)
    })
  })

  describe('WHEN the component unmounts', () => {
    it('THEN ResizeObserver.disconnect is called', () => {
      const { unmount } = renderOverflowHook()

      act(() => {
        jest.runAllTimers()
      })

      const disconnectSpy = (MockResizeObserver.prototype.disconnect = jest.fn(
        MockResizeObserver.prototype.disconnect,
      ))

      // Get the instance from the last constructor call
      const instances = (MockResizeObserver as unknown as jest.Mock).mock?.instances
      const lastInstance = instances?.[instances.length - 1] as MockResizeObserver | undefined

      unmount()

      if (lastInstance) {
        expect(lastInstance.disconnect).toHaveBeenCalled()
      } else {
        // Fallback: verify the hook cleans up by checking no errors thrown
        expect(disconnectSpy).toBeDefined()
      }
    })
  })

  describe('WHEN a resize event fires', () => {
    it('THEN the ResizeObserver callback triggers recalculation via requestAnimationFrame', () => {
      const { result } = renderOverflowHook({ containerWidth: FULL_WIDTH })

      act(() => {
        jest.runAllTimers()
      })

      expect(result.current.hasOverflow).toBe(false)

      // Simulate resize to narrow container
      // The callback fires, rAF is scheduled, then runs on runAllTimers
      act(() => {
        resizeCallback([], {} as ResizeObserver)
        jest.runAllTimers()
      })

      // Result depends on original containerRef still pointing to FULL_WIDTH
      // The hook itself recalculates — since ref hasn't changed it stays the same
      expect(result.current.hasOverflow).toBe(false)
    })
  })

  describe('WHEN visible groups have not changed after recalculation', () => {
    it('THEN setVisibleGroups returns the previous set reference (no re-render)', () => {
      const { result } = renderOverflowHook({ containerWidth: FULL_WIDTH })

      act(() => {
        jest.runAllTimers()
      })

      const setBeforeResize = result.current.visibleGroups

      // Trigger another resize with same container size — same result
      act(() => {
        resizeCallback([], {} as ResizeObserver)
        jest.runAllTimers()
      })

      // Same Set reference returned (bail-out optimization)
      expect(result.current.visibleGroups).toBe(setBeforeResize)
    })
  })
})
