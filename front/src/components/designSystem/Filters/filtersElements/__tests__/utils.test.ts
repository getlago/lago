import { formatMultiFilterValue, parseMultiFilterValue } from '../utils'

describe('filtersElements utils', () => {
  describe('parseMultiFilterValue', () => {
    describe('GIVEN a comma-separated string', () => {
      describe('WHEN the string contains multiple values', () => {
        it('THEN should return an array of { value } objects', () => {
          const result = parseMultiFilterValue('a,b,c')

          expect(result).toEqual([{ value: 'a' }, { value: 'b' }, { value: 'c' }])
        })
      })

      describe('WHEN the string contains a single value', () => {
        it('THEN should return an array with one object', () => {
          const result = parseMultiFilterValue('only')

          expect(result).toEqual([{ value: 'only' }])
        })
      })
    })

    describe('GIVEN an empty or nullish input', () => {
      describe('WHEN value is an empty string', () => {
        it('THEN should return an empty array', () => {
          const result = parseMultiFilterValue('')

          expect(result).toEqual([])
        })
      })

      describe('WHEN value is undefined', () => {
        it('THEN should return an empty array', () => {
          const result = parseMultiFilterValue(undefined)

          expect(result).toEqual([])
        })
      })

      describe('WHEN value is not provided', () => {
        it('THEN should return an empty array', () => {
          const result = parseMultiFilterValue()

          expect(result).toEqual([])
        })
      })
    })

    describe('GIVEN a string with empty segments', () => {
      describe('WHEN the string has a trailing comma', () => {
        it('THEN should filter out empty segments', () => {
          const result = parseMultiFilterValue('a,b,')

          expect(result).toEqual([{ value: 'a' }, { value: 'b' }])
        })
      })

      describe('WHEN the string has a leading comma', () => {
        it('THEN should filter out empty segments', () => {
          const result = parseMultiFilterValue(',a,b')

          expect(result).toEqual([{ value: 'a' }, { value: 'b' }])
        })
      })

      describe('WHEN the string is only commas', () => {
        it('THEN should return an empty array', () => {
          const result = parseMultiFilterValue(',,')

          expect(result).toEqual([])
        })
      })
    })
  })

  describe('formatMultiFilterValue', () => {
    describe('GIVEN an array of { value } objects', () => {
      describe('WHEN the array has multiple items', () => {
        it('THEN should join values with commas', () => {
          const result = formatMultiFilterValue([{ value: 'a' }, { value: 'b' }, { value: 'c' }])

          expect(result).toBe('a,b,c')
        })
      })

      describe('WHEN the array has a single item', () => {
        it('THEN should return the value without commas', () => {
          const result = formatMultiFilterValue([{ value: 'only' }])

          expect(result).toBe('only')
        })
      })
    })

    describe('GIVEN an empty array', () => {
      describe('WHEN no items are provided', () => {
        it('THEN should return an empty string', () => {
          const result = formatMultiFilterValue([])

          expect(result).toBe('')
        })
      })
    })
  })

  describe('roundtrip', () => {
    describe('GIVEN a formatted value', () => {
      describe('WHEN parsed and re-formatted', () => {
        it.each([['a,b,c'], ['single'], ['succeeded,failed,pending'], ['2xx,5xx']])(
          'THEN should produce the original value: "%s"',
          (original) => {
            const parsed = parseMultiFilterValue(original)
            const formatted = formatMultiFilterValue(parsed)

            expect(formatted).toBe(original)
          },
        )
      })
    })
  })
})
