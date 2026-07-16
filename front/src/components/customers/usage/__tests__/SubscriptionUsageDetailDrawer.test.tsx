import {
  isBreakdownRow,
  makeBreakdownRows,
  sumBreakdownUnits,
} from '~/components/customers/usage/SubscriptionUsageDetailDrawer'
import {
  dedupeTailBreakdowns,
  isMeaningfulPresentationValue,
} from '~/components/customers/usage/usageDetailsHelpers'

describe('SubscriptionUsageDetailDrawer helpers', () => {
  describe('sumBreakdownUnits', () => {
    describe('GIVEN no breakdowns', () => {
      it.each([
        ['null', null],
        ['undefined', undefined],
        ['empty array', []],
      ])('WHEN passed %s THEN should return 0', (_, input) => {
        expect(sumBreakdownUnits(input as never)).toBe(0)
      })
    })

    describe('GIVEN breakdowns with numeric units', () => {
      it('WHEN summing THEN should add every entry', () => {
        const breakdowns = [{ units: '10' }, { units: '20.5' }, { units: '3' }]

        expect(sumBreakdownUnits(breakdowns)).toBe(33.5)
      })
    })

    describe('GIVEN breakdowns with non-numeric units', () => {
      it('WHEN summing THEN should treat invalid values as 0', () => {
        const breakdowns = [{ units: '10' }, { units: 'not-a-number' }, { units: '5' }]

        expect(sumBreakdownUnits(breakdowns)).toBe(15)
      })
    })
  })

  describe('isBreakdownRow', () => {
    describe('WHEN given a row marked with __isBreakdown', () => {
      it('THEN should return true', () => {
        const row = {
          id: 'x',
          __isBreakdown: true,
          presentationBy: {},
          breakdownUnits: '0',
        }

        expect(isBreakdownRow(row)).toBe(true)
      })
    })

    describe.each([
      ['null', null],
      ['undefined', undefined],
      ['plain object without flag', { id: 'r', units: 1 }],
      ['number', 42],
      ['string', 'breakdown'],
    ])('WHEN given %s', (_, value) => {
      it('THEN should return false', () => {
        expect(isBreakdownRow(value)).toBe(false)
      })
    })
  })

  describe('makeBreakdownRows', () => {
    describe('GIVEN no breakdowns', () => {
      it.each([
        ['null', null],
        ['undefined', undefined],
        ['empty array', []],
      ])('WHEN passed %s THEN should return an empty array', (_, input) => {
        expect(makeBreakdownRows('parent', input as never)).toEqual([])
      })
    })

    describe('GIVEN distinct presentationBy keys', () => {
      it('WHEN aggregating THEN should emit one row per unique key', () => {
        const result = makeBreakdownRows('parent', [
          { presentationBy: { region: 'us' }, units: '10' },
          { presentationBy: { region: 'eu' }, units: '20' },
        ])

        expect(result).toHaveLength(2)
        expect(result.map((r) => r.presentationBy)).toEqual([{ region: 'us' }, { region: 'eu' }])
      })

      it('THEN should expose units as a string and a synthetic id', () => {
        const result = makeBreakdownRows('parent', [
          { presentationBy: { region: 'us' }, units: '10' },
        ])

        expect(result[0]).toEqual(
          expect.objectContaining({
            id: 'parent__breakdown__0',
            __isBreakdown: true,
            presentationBy: { region: 'us' },
            breakdownUnits: '10',
          }),
        )
      })
    })

    describe('GIVEN duplicate presentationBy values', () => {
      it('WHEN aggregating THEN should sum the units into one row', () => {
        const result = makeBreakdownRows('p', [
          { presentationBy: { region: 'us' }, units: '6' },
          { presentationBy: { region: 'us' }, units: '18' },
          { presentationBy: { region: 'us' }, units: '3' },
          { presentationBy: { region: 'eu' }, units: '6' },
        ])

        expect(result).toHaveLength(2)
        const us = result.find((r) => r.presentationBy.region === 'us')
        const eu = result.find((r) => r.presentationBy.region === 'eu')

        expect(us?.breakdownUnits).toBe('27')
        expect(eu?.breakdownUnits).toBe('6')
      })
    })

    describe('GIVEN composite presentationBy keys', () => {
      it('WHEN keys are in different order THEN should treat them as the same group', () => {
        const result = makeBreakdownRows('p', [
          { presentationBy: { region: 'us', tier: 'gold' }, units: '5' },
          { presentationBy: { tier: 'gold', region: 'us' }, units: '7' },
        ])

        expect(result).toHaveLength(1)
        expect(result[0].breakdownUnits).toBe('12')
      })
    })

    describe('GIVEN an empty presentationBy object', () => {
      it('WHEN aggregating THEN should keep the row (rendered as an empty name + units)', () => {
        const result = makeBreakdownRows('p', [{ presentationBy: {}, units: '8' }])

        expect(result).toHaveLength(1)
        expect(result[0].presentationBy).toEqual({})
        expect(result[0].breakdownUnits).toBe('8')
      })
    })

    describe('GIVEN a presentationBy object where every value is null/undefined', () => {
      it('WHEN aggregating THEN should keep the row (chips are filtered per-value in the cell)', () => {
        const result = makeBreakdownRows('p', [
          { presentationBy: { region: null, tier: undefined }, units: '8' },
        ])

        expect(result).toHaveLength(1)
        expect(result[0].presentationBy).toEqual({ region: null, tier: undefined })
        expect(result[0].breakdownUnits).toBe('8')
      })
    })

    describe('GIVEN a presentationBy object where some values are null and some are set', () => {
      it('WHEN aggregating THEN should keep the row with the original keys intact', () => {
        const result = makeBreakdownRows('p', [
          { presentationBy: { region: 'us', tier: null }, units: '5' },
        ])

        expect(result).toHaveLength(1)
        expect(result[0].presentationBy).toEqual({ region: 'us', tier: null })
      })
    })
  })

  describe('dedupeTailBreakdowns', () => {
    describe('GIVEN an empty / missing tail', () => {
      it.each([
        ['null', null],
        ['undefined', undefined],
        ['empty array', []],
      ])('WHEN passed %s THEN should return []', (_, tail) => {
        expect(dedupeTailBreakdowns([], tail as never)).toEqual([])
      })
    })

    describe('GIVEN the tail duplicates a filter breakdown', () => {
      it('WHEN deduping THEN should drop the duplicate entry', () => {
        const filterBreakdowns = [{ presentationBy: { department: 'eng' }, units: '3.0' }]
        const tail = [{ presentationBy: { department: 'eng' }, units: '3.0' }]

        expect(dedupeTailBreakdowns([filterBreakdowns], tail)).toEqual([])
      })
    })

    describe('GIVEN the tail contains both duplicates and unique entries', () => {
      it('WHEN deduping THEN should keep only the entries not seen in filters', () => {
        const filterBreakdowns = [{ presentationBy: { department: 'eng' }, units: '3.0' }]
        const tail = [
          { presentationBy: { department: 'eng' }, units: '3.0' },
          { presentationBy: { department: 'sales' }, units: '5.0' },
        ]

        expect(dedupeTailBreakdowns([filterBreakdowns], tail)).toEqual([
          { presentationBy: { department: 'sales' }, units: '5.0' },
        ])
      })
    })

    describe('GIVEN multiple filter sets', () => {
      it('WHEN deduping THEN should consider keys from any set', () => {
        const filterA = [{ presentationBy: { department: 'eng' }, units: '3.0' }]
        const filterB = [{ presentationBy: { department: 'sales' }, units: '5.0' }]
        const tail = [
          { presentationBy: { department: 'eng' }, units: '3.0' },
          { presentationBy: { department: 'sales' }, units: '5.0' },
          { presentationBy: { department: 'ops' }, units: '1.0' },
        ]

        expect(dedupeTailBreakdowns([filterA, filterB], tail)).toEqual([
          { presentationBy: { department: 'ops' }, units: '1.0' },
        ])
      })
    })

    describe('GIVEN composite presentationBy keys in a different order', () => {
      it('WHEN deduping THEN should still treat them as duplicates', () => {
        const filterBreakdowns = [{ presentationBy: { region: 'us', tier: 'gold' }, units: '3.0' }]
        const tail = [{ presentationBy: { tier: 'gold', region: 'us' }, units: '3.0' }]

        expect(dedupeTailBreakdowns([filterBreakdowns], tail)).toEqual([])
      })
    })

    describe('GIVEN null entries in alreadyRendered', () => {
      it('WHEN deduping THEN should ignore them and not throw', () => {
        const tail = [{ presentationBy: { department: 'eng' }, units: '3.0' }]

        expect(dedupeTailBreakdowns([null, undefined, []], tail)).toEqual(tail)
      })
    })
  })

  describe('isMeaningfulPresentationValue', () => {
    describe.each([
      ['null', null],
      ['undefined', undefined],
      ['empty string', ''],
    ])('GIVEN %s', (_, value) => {
      it('THEN returns false', () => {
        expect(isMeaningfulPresentationValue(value)).toBe(false)
      })
    })

    describe.each([
      ['non-empty string', 'us'],
      ['zero', 0],
      ['a number', 42],
      ['false', false],
      ['an object', {}],
    ])('GIVEN %s', (_, value) => {
      it('THEN returns true', () => {
        expect(isMeaningfulPresentationValue(value)).toBe(true)
      })
    })
  })
})
