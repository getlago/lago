import { renderHook } from '@testing-library/react'

import { useOrdersColumns } from '../useOrdersColumns'

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

describe('useOrdersColumns', () => {
  it('includes the source-quote column when hideSourceQuote is false', () => {
    const { result } = renderHook(() => useOrdersColumns({ hideSourceQuote: false }))

    expect(result.current.map((c) => c.key)).toEqual([
      'number',
      'status',
      'orderForm.quote.number',
      'orderForm.number',
      'executionMode',
      'executedAt',
    ])
    expect(result.current[0].title).toBe('text_1782392058759pmmuy0h997w')
  })

  it('omits the source-quote column when hideSourceQuote is true', () => {
    const { result } = renderHook(() => useOrdersColumns({ hideSourceQuote: true }))

    expect(result.current.map((c) => c.key)).toEqual([
      'number',
      'status',
      'orderForm.number',
      'executionMode',
      'executedAt',
    ])
  })
})
