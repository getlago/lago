import { encodeRison } from '~/core/utils/risonEncoder'

describe('encodeRison', () => {
  it('encodes a string without special characters', () => {
    expect(encodeRison('Currency')).toBe('Currency')
  })

  it('encodes a string with spaces using single quotes', () => {
    expect(encodeRison('Last quarter')).toBe("'Last quarter'")
  })

  it('encodes a string containing a single quote', () => {
    expect(encodeRison("it's")).toBe("'it!'s'")
  })

  it('encodes RISON keyword-like strings with quotes and escaped !', () => {
    expect(encodeRison('!t')).toBe("'!!t'")
    expect(encodeRison('!f')).toBe("'!!f'")
    expect(encodeRison('!n')).toBe("'!!n'")
  })

  it('encodes an empty string with single quotes', () => {
    expect(encodeRison('')).toBe("''")
  })

  it('encodes a number', () => {
    expect(encodeRison(42)).toBe('42')
    expect(encodeRison(3.14)).toBe('3.14')
  })

  it('encodes booleans', () => {
    expect(encodeRison(true)).toBe('!t')
    expect(encodeRison(false)).toBe('!f')
  })

  it('encodes null', () => {
    expect(encodeRison(null)).toBe('!n')
  })

  it('encodes an empty array', () => {
    expect(encodeRison([])).toBe('!()')
  })

  it('encodes an array of strings', () => {
    expect(encodeRison(['EUR', 'USD'])).toBe('!(EUR,USD)')
  })

  it('encodes an empty object', () => {
    expect(encodeRison({})).toBe('()')
  })

  it('encodes a simple object', () => {
    expect(encodeRison({ label: 'Currency', value: 'EUR' })).toBe('(label:Currency,value:EUR)')
  })

  it('encodes a nested filter state object', () => {
    const input = {
      'NATIVE_FILTER-abc': {
        filterState: {
          value: ['EUR'],
          excludeFilterValues: true,
          label: 'Currency',
        },
      },
    }

    expect(encodeRison(input)).toBe(
      '(NATIVE_FILTER-abc:(filterState:(value:!(EUR),excludeFilterValues:!t,label:Currency)))',
    )
  })

  it('encodes a realistic multi-filter object', () => {
    const input = {
      'NATIVE_FILTER-oFKcx8PxGN0bMEs0162b': {
        filterState: {
          value: 'Last quarter',
        },
      },
      'NATIVE_FILTER-60Cxt1g_5G-Phhv5JyBFR': {
        filterState: {
          value: ['Currency'],
          excludeFilterValues: true,
          label: 'Currency',
        },
      },
    }

    expect(encodeRison(input)).toBe(
      "(NATIVE_FILTER-oFKcx8PxGN0bMEs0162b:(filterState:(value:'Last quarter'))" +
        ',NATIVE_FILTER-60Cxt1g_5G-Phhv5JyBFR:(filterState:(value:!(Currency),excludeFilterValues:!t,label:Currency)))',
    )
  })
})
