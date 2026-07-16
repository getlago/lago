import { ThresholdInput } from '~/generated/graphql'

import { isThresholdValueValid } from '../Thresholds'

const buildThresholds = (...values: string[]): ThresholdInput[] =>
  values.map((value, i) => ({
    code: `threshold_${i}`,
    value,
    recurring: false,
  }))

describe('isThresholdValueValid', () => {
  describe('GIVEN index is 0', () => {
    it('WHEN called with any value THEN returns false', () => {
      const thresholds = buildThresholds('100')

      expect(isThresholdValueValid(0, '50', thresholds)).toBe(false)
    })
  })

  describe('GIVEN value is an empty string', () => {
    it('WHEN called with index > 0 THEN returns false', () => {
      const thresholds = buildThresholds('100', '')

      expect(isThresholdValueValid(1, '', thresholds)).toBe(false)
    })
  })

  describe('GIVEN normal mode (reverse is not set)', () => {
    it.each([
      { current: '50', previous: '100', expected: true, scenario: 'current < previous' },
      { current: '100', previous: '100', expected: true, scenario: 'current equals previous' },
      { current: '150', previous: '100', expected: false, scenario: 'current > previous' },
    ])('WHEN $scenario THEN returns $expected', ({ current, previous, expected }) => {
      const thresholds = buildThresholds(previous, current)

      expect(isThresholdValueValid(1, current, thresholds)).toBe(expected)
    })
  })

  describe('GIVEN reverse mode', () => {
    it.each([
      { current: '150', previous: '100', expected: true, scenario: 'current > previous' },
      { current: '100', previous: '100', expected: true, scenario: 'current equals previous' },
      { current: '50', previous: '100', expected: false, scenario: 'current < previous' },
    ])('WHEN $scenario THEN returns $expected', ({ current, previous, expected }) => {
      const thresholds = buildThresholds(previous, current)

      expect(isThresholdValueValid(1, current, thresholds, true)).toBe(expected)
    })
  })

  describe('GIVEN equal values', () => {
    it('WHEN normal mode THEN returns true (value <= previous)', () => {
      const thresholds = buildThresholds('200', '200')

      expect(isThresholdValueValid(1, '200', thresholds)).toBe(true)
    })

    it('WHEN reverse mode THEN returns true (value >= previous)', () => {
      const thresholds = buildThresholds('200', '200')

      expect(isThresholdValueValid(1, '200', thresholds, true)).toBe(true)
    })
  })
})
