import { renderHook } from '@testing-library/react'

import { useGetRangeLabel } from '../useGetRangeLabel'

let mockTranslations: Record<string, string> = {}

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string, variables?: Record<string, unknown>) => {
      const template = mockTranslations[key] || key

      if (!variables) return template
      return template.replace(/\{\{(\w+)\}\}/g, (_, varName) => String(variables[varName] ?? ''))
    },
  }),
}))

describe('useGetRangeLabel', () => {
  beforeEach(() => {
    mockTranslations = {
      // Flat variants
      text_659e67cd63512ef53284314a: 'From {{fromValue}}',
      text_659e67cd63512ef53284310e: 'Up to {{toValue}}',
      text_659e67cd63512ef532843136: 'From {{fromValue}} to {{toValue}}',
      // Non-flat variants
      text_659e67cd63512ef5328430e6: 'From {{fromValue}} units',
      text_659e67cd63512ef532843070: 'First {{toValue}} units',
      text_659e67cd63512ef5328430af: '{{fromValue}} to {{toValue}} units',
    }
  })

  describe('getRangeLabel', () => {
    describe('when totalLength is 1 (single tier)', () => {
      it('returns "From X" label for flat pricing', () => {
        const { result } = renderHook(() => useGetRangeLabel())
        const label = result.current.getRangeLabel(0, 1, 0, 100, true)

        expect(label).toBe('From 0')
      })

      it('returns "From X units" label for non-flat pricing', () => {
        const { result } = renderHook(() => useGetRangeLabel())
        const label = result.current.getRangeLabel(0, 1, 0, 100, false)

        expect(label).toBe('From 0 units')
      })
    })

    describe('when index is 0 (first tier of multiple)', () => {
      it('returns "Up to X" label for flat pricing', () => {
        const { result } = renderHook(() => useGetRangeLabel())
        const label = result.current.getRangeLabel(0, 3, 0, 10, true)

        expect(label).toBe('Up to 10')
      })

      it('returns "First X units" label for non-flat pricing', () => {
        const { result } = renderHook(() => useGetRangeLabel())
        const label = result.current.getRangeLabel(0, 3, 0, 10, false)

        expect(label).toBe('First 10 units')
      })
    })

    describe('when index is last (index === totalLength - 1)', () => {
      it('returns "From X" label for flat pricing with 3 tiers', () => {
        const { result } = renderHook(() => useGetRangeLabel())
        // index=2, totalLength=3 => 2 === 3-1 is true
        const label = result.current.getRangeLabel(2, 3, 21, 999, true)

        expect(label).toBe('From 21')
      })

      it('returns "From X units" label for non-flat pricing with 3 tiers', () => {
        const { result } = renderHook(() => useGetRangeLabel())
        // index=2, totalLength=3 => 2 === 3-1 is true
        const label = result.current.getRangeLabel(2, 3, 21, 999, false)

        expect(label).toBe('From 21 units')
      })

      it('returns "From X" label for flat pricing with 4 tiers', () => {
        const { result } = renderHook(() => useGetRangeLabel())
        // index=3, totalLength=4 => 3 === 4-1 is true
        const label = result.current.getRangeLabel(3, 4, 31, 999, true)

        expect(label).toBe('From 31')
      })

      it('returns "From X units" label for non-flat pricing with 4 tiers', () => {
        const { result } = renderHook(() => useGetRangeLabel())
        // index=3, totalLength=4 => 3 === 4-1 is true
        const label = result.current.getRangeLabel(3, 4, 31, 999, false)

        expect(label).toBe('From 31 units')
      })
    })

    describe('when index is in the middle', () => {
      it('returns "From X to Y" label for flat pricing', () => {
        const { result } = renderHook(() => useGetRangeLabel())
        const label = result.current.getRangeLabel(1, 3, 11, 20, true)

        expect(label).toBe('From 11 to 20')
      })

      it('returns "X to Y units" label for non-flat pricing', () => {
        const { result } = renderHook(() => useGetRangeLabel())
        const label = result.current.getRangeLabel(1, 3, 11, 20, false)

        expect(label).toBe('11 to 20 units')
      })
    })

    describe('edge cases', () => {
      it('handles two tiers correctly for first tier', () => {
        const { result } = renderHook(() => useGetRangeLabel())
        const label = result.current.getRangeLabel(0, 2, 0, 10, true)

        expect(label).toBe('Up to 10')
      })

      it('handles two tiers correctly for last tier', () => {
        const { result } = renderHook(() => useGetRangeLabel())
        const label = result.current.getRangeLabel(1, 2, 11, 999, true)

        expect(label).toBe('From 11')
      })

      it('handles large values correctly', () => {
        const { result } = renderHook(() => useGetRangeLabel())
        const label = result.current.getRangeLabel(1, 4, 1000000, 2000000, false)

        expect(label).toBe('1000000 to 2000000 units')
      })
    })
  })
})
