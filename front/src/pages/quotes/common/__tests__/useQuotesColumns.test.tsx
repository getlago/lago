import { renderHook } from '@testing-library/react'

import { useQuotesColumns } from '../useQuotesColumns'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    intlFormatDateTimeOrgaTZ: (date: string) => ({
      date: new Date(date).toLocaleDateString('en-US'),
    }),
  }),
}))

describe('useQuotesColumns', () => {
  it('returns the expected columns in order, with "Quote number" title key', () => {
    const { result } = renderHook(() => useQuotesColumns())

    expect(result.current.map((c) => c.key)).toEqual([
      'number',
      'customer.displayName',
      'versions.0.status',
      'versions.0.version',
      'orderType',
      'createdAt',
    ])
    // number column uses the quote-number key
    expect(result.current[0].title).toBe('text_1775746196826pyjlfqx3anr')
  })
})
