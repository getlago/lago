import { extractNativeFilters } from '~/core/utils/supersetFilters'

describe('extractNativeFilters', () => {
  describe('GIVEN an empty dataMask', () => {
    describe('WHEN called with no entries', () => {
      it('THEN should return an empty object', () => {
        expect(extractNativeFilters({})).toEqual({})
      })
    })
  })

  describe('GIVEN entries without NATIVE_FILTER- prefix', () => {
    describe('WHEN called with non-native filter keys', () => {
      it('THEN should skip all entries', () => {
        const dataMask = {
          'OTHER_KEY-abc': { filterState: { value: 'EUR' } },
          'SOME_FILTER-xyz': { filterState: { value: ['USD'] } },
        }

        expect(extractNativeFilters(dataMask)).toEqual({})
      })
    })
  })

  describe('GIVEN entries with missing filterState', () => {
    describe('WHEN filterState is undefined', () => {
      it('THEN should skip the entry', () => {
        const dataMask = {
          'NATIVE_FILTER-abc': {},
        }

        expect(extractNativeFilters(dataMask)).toEqual({})
      })
    })
  })

  describe('GIVEN entries with null or undefined values', () => {
    describe('WHEN filterState.value is null', () => {
      it('THEN should skip the entry', () => {
        const dataMask = {
          'NATIVE_FILTER-abc': { filterState: { value: null } },
        }

        expect(extractNativeFilters(dataMask)).toEqual({})
      })
    })

    describe('WHEN filterState.value is undefined', () => {
      it('THEN should skip the entry', () => {
        const dataMask = {
          'NATIVE_FILTER-abc': { filterState: { value: undefined } },
        }

        expect(extractNativeFilters(dataMask)).toEqual({})
      })
    })
  })

  describe('GIVEN entries with empty array values', () => {
    describe('WHEN filterState.value is an empty array', () => {
      it('THEN should skip the entry', () => {
        const dataMask = {
          'NATIVE_FILTER-abc': { filterState: { value: [] } },
        }

        expect(extractNativeFilters(dataMask)).toEqual({})
      })
    })
  })

  describe('GIVEN entries with valid filter values', () => {
    describe('WHEN filterState.value is a non-empty array', () => {
      it('THEN should include the entry', () => {
        const dataMask = {
          'NATIVE_FILTER-abc': { filterState: { value: ['EUR'] } },
        }

        expect(extractNativeFilters(dataMask)).toEqual({
          'NATIVE_FILTER-abc': { filterState: { value: ['EUR'] } },
        })
      })
    })

    describe('WHEN filterState.value is a string', () => {
      it('THEN should include the entry', () => {
        const dataMask = {
          'NATIVE_FILTER-abc': { filterState: { value: 'Last quarter' } },
        }

        expect(extractNativeFilters(dataMask)).toEqual({
          'NATIVE_FILTER-abc': { filterState: { value: 'Last quarter' } },
        })
      })
    })

    describe('WHEN filterState.value is a number', () => {
      it('THEN should include the entry', () => {
        const dataMask = {
          'NATIVE_FILTER-abc': { filterState: { value: 42 } },
        }

        expect(extractNativeFilters(dataMask)).toEqual({
          'NATIVE_FILTER-abc': { filterState: { value: 42 } },
        })
      })
    })

    describe('WHEN filterState.value is a boolean', () => {
      it('THEN should include the entry', () => {
        const dataMask = {
          'NATIVE_FILTER-abc': { filterState: { value: true } },
        }

        expect(extractNativeFilters(dataMask)).toEqual({
          'NATIVE_FILTER-abc': { filterState: { value: true } },
        })
      })
    })
  })

  describe('GIVEN a mix of valid and invalid entries', () => {
    describe('WHEN dataMask contains multiple entries', () => {
      it('THEN should only include valid native filter entries', () => {
        const dataMask = {
          'NATIVE_FILTER-valid1': { filterState: { value: ['EUR'], label: 'Currency' } },
          'NATIVE_FILTER-nullVal': { filterState: { value: null } },
          'NATIVE_FILTER-emptyArr': { filterState: { value: [] } },
          'NATIVE_FILTER-valid2': { filterState: { value: 'Last quarter' } },
          'OTHER_KEY-skip': { filterState: { value: 'something' } },
          'NATIVE_FILTER-noState': {},
        }

        const result = extractNativeFilters(dataMask)

        expect(Object.keys(result)).toHaveLength(2)
        expect(result).toEqual({
          'NATIVE_FILTER-valid1': { filterState: { value: ['EUR'], label: 'Currency' } },
          'NATIVE_FILTER-valid2': { filterState: { value: 'Last quarter' } },
        })
      })
    })
  })

  describe('GIVEN entries with extra filterState properties', () => {
    describe('WHEN filterState has additional fields beyond value', () => {
      it('THEN should preserve the full filterState object', () => {
        const dataMask = {
          'NATIVE_FILTER-abc': {
            filterState: {
              value: ['EUR'],
              excludeFilterValues: true,
              label: 'Currency',
            },
          },
        }

        expect(extractNativeFilters(dataMask)).toEqual({
          'NATIVE_FILTER-abc': {
            filterState: {
              value: ['EUR'],
              excludeFilterValues: true,
              label: 'Currency',
            },
          },
        })
      })
    })
  })
})
