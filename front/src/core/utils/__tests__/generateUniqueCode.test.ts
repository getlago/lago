import { generateUniqueCode } from '~/core/utils/generateUniqueCode'

describe('generateUniqueCode', () => {
  it('returns the base when it does not collide', () => {
    expect(generateUniqueCode('sum_bm', [])).toBe('sum_bm')
    expect(generateUniqueCode('sum_bm', ['other'])).toBe('sum_bm')
  })

  it('appends _2 on the first collision', () => {
    expect(generateUniqueCode('sum_bm', ['sum_bm'])).toBe('sum_bm_2')
  })

  it('increments the suffix until it finds a free code', () => {
    expect(generateUniqueCode('sum_bm', ['sum_bm', 'sum_bm_2', 'sum_bm_3'])).toBe('sum_bm_4')
  })

  it('ignores null/undefined entries', () => {
    expect(generateUniqueCode('sum_bm', [null, undefined, 'sum_bm'])).toBe('sum_bm_2')
  })

  it('returns an empty base unchanged', () => {
    expect(generateUniqueCode('', ['sum_bm'])).toBe('')
  })
})
