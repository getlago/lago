import { renderHook } from '@testing-library/react'
import { ReactNode } from 'react'
import { MemoryRouter } from 'react-router-dom'

import {
  InvoicePaymentStatusTypeEnum,
  InvoiceStatusTypeEnum,
  TimeGranularityEnum,
} from '~/generated/graphql'

import { FilterContext } from '../context'
import { AvailableFiltersEnum } from '../types'
import { useFilters } from '../useFilters'
import {
  isDraftUrlParams,
  isOutstandingUrlParams,
  isPaymentDisputeLostUrlParams,
  isPaymentOverdueUrlParams,
  isSucceededUrlParams,
  isVoidedUrlParams,
} from '../utils'

const FILTER_PREFIX = 'f'

const staticFilters = {
  currency: 'eur',
}
const staticQuickFilters = {
  timeGranularity: 'daily',
}

const wrapper = ({
  children,
  withStaticFilters,
  withStaticQuickFilters,
  initialSearchParams,
}: {
  children: ReactNode
  withStaticFilters: boolean
  withStaticQuickFilters: boolean
  initialSearchParams?: string
}): JSX.Element => {
  return (
    <MemoryRouter initialEntries={initialSearchParams ? [`/?${initialSearchParams}`] : ['/']}>
      <div>
        <FilterContext.Provider
          value={{
            filtersNamePrefix: FILTER_PREFIX,
            staticFilters: withStaticFilters ? staticFilters : {},
            staticQuickFilters: withStaticQuickFilters ? staticQuickFilters : {},
            availableFilters: [
              AvailableFiltersEnum.status,
              AvailableFiltersEnum.invoiceType,
              AvailableFiltersEnum.currency,
              AvailableFiltersEnum.paymentStatus,
              AvailableFiltersEnum.paymentOverdue,
              AvailableFiltersEnum.paymentDisputeLost,
              AvailableFiltersEnum.date,
              AvailableFiltersEnum.timeGranularity,
            ],
          }}
        >
          {children}
        </FilterContext.Provider>
      </div>
    </MemoryRouter>
  )
}

describe('draft', () => {
  it('should return search params without initial static filters', () => {
    const { result } = renderHook(() => useFilters(), {
      wrapper: ({ children }) =>
        wrapper({ children, withStaticFilters: false, withStaticQuickFilters: false }),
    })

    const expectedSearchParams = 'f_status=draft'

    expect(
      result.current.buildQuickFilterUrlParams({
        status: InvoiceStatusTypeEnum.Draft,
      }),
    ).toEqual(expectedSearchParams)

    const draftSearchParams = new Map(
      new URLSearchParams(`?${expectedSearchParams}`).entries(),
    ) as unknown as URLSearchParams

    expect(isDraftUrlParams({ prefix: FILTER_PREFIX, searchParams: draftSearchParams })).toBe(true)
  })
  it('should return search params with initial static filters', () => {
    const { result } = renderHook(() => useFilters(), {
      wrapper: ({ children }) =>
        wrapper({ children, withStaticFilters: true, withStaticQuickFilters: false }),
    })

    const expectedSearchParams = 'f_currency=eur&f_status=draft'

    const draftSearchParams = new Map(
      new URLSearchParams(`?${expectedSearchParams}`).entries(),
    ) as unknown as URLSearchParams

    expect(
      result.current.buildQuickFilterUrlParams({
        status: InvoiceStatusTypeEnum.Draft,
      }),
    ).toEqual(expectedSearchParams)
    expect(isDraftUrlParams({ prefix: FILTER_PREFIX, searchParams: draftSearchParams })).toBe(true)
  })
})

describe('outstanding', () => {
  it('should return search params without initial static filters', () => {
    const { result } = renderHook(() => useFilters(), {
      wrapper: ({ children }) =>
        wrapper({ children, withStaticFilters: false, withStaticQuickFilters: false }),
    })

    const expectedSearchParams = 'f_paymentStatus=failed,pending&f_status=finalized'

    expect(
      result.current.buildQuickFilterUrlParams({
        paymentStatus: [InvoicePaymentStatusTypeEnum.Failed, InvoicePaymentStatusTypeEnum.Pending],
        status: InvoiceStatusTypeEnum.Finalized,
      }),
    ).toEqual(expectedSearchParams)

    const outstandingSearchParams = new Map(
      new URLSearchParams(`?${expectedSearchParams}`).entries(),
    ) as unknown as URLSearchParams

    expect(
      isOutstandingUrlParams({ prefix: FILTER_PREFIX, searchParams: outstandingSearchParams }),
    ).toBe(true)
  })
  it('should return search params with initial static filters', () => {
    const { result } = renderHook(() => useFilters(), {
      wrapper: ({ children }) =>
        wrapper({ children, withStaticFilters: true, withStaticQuickFilters: false }),
    })

    const expectedSearchParams = 'f_currency=eur&f_paymentStatus=failed,pending&f_status=finalized'

    expect(
      result.current.buildQuickFilterUrlParams({
        paymentStatus: [InvoicePaymentStatusTypeEnum.Failed, InvoicePaymentStatusTypeEnum.Pending],
        status: InvoiceStatusTypeEnum.Finalized,
      }),
    ).toEqual(expectedSearchParams)

    const outstandingSearchParams = new Map(
      new URLSearchParams(`?${expectedSearchParams}`).entries(),
    ) as unknown as URLSearchParams

    expect(
      isOutstandingUrlParams({ prefix: FILTER_PREFIX, searchParams: outstandingSearchParams }),
    ).toBe(true)
  })
})

describe('payment overdue', () => {
  it('should return search params without initial static filters', () => {
    const { result } = renderHook(() => useFilters(), {
      wrapper: ({ children }) =>
        wrapper({ children, withStaticFilters: false, withStaticQuickFilters: false }),
    })

    const expectedSearchParams = 'f_paymentOverdue=true'

    expect(
      result.current.buildQuickFilterUrlParams({
        paymentOverdue: true,
      }),
    ).toEqual(expectedSearchParams)

    const paymentOverdueSearchParams = new Map(
      new URLSearchParams(`?${expectedSearchParams}`).entries(),
    ) as unknown as URLSearchParams

    expect(
      isPaymentOverdueUrlParams({
        prefix: FILTER_PREFIX,
        searchParams: paymentOverdueSearchParams,
      }),
    ).toBe(true)
  })
  it('should return search params with initial static filters', () => {
    const { result } = renderHook(() => useFilters(), {
      wrapper: ({ children }) =>
        wrapper({ children, withStaticFilters: true, withStaticQuickFilters: false }),
    })

    const expectedSearchParams = 'f_currency=eur&f_paymentOverdue=true'

    expect(
      result.current.buildQuickFilterUrlParams({
        paymentOverdue: true,
      }),
    ).toEqual(expectedSearchParams)

    const paymentOverdueSearchParams = new Map(
      new URLSearchParams(`?${expectedSearchParams}`).entries(),
    ) as unknown as URLSearchParams

    expect(
      isPaymentOverdueUrlParams({
        prefix: FILTER_PREFIX,
        searchParams: paymentOverdueSearchParams,
      }),
    ).toBe(true)
  })
})

describe('succeeded', () => {
  it('should return search params without initial static filters', () => {
    const { result } = renderHook(() => useFilters(), {
      wrapper: ({ children }) =>
        wrapper({ children, withStaticFilters: false, withStaticQuickFilters: false }),
    })

    const expectedSearchParams = 'f_paymentStatus=succeeded&f_status=finalized'

    expect(
      result.current.buildQuickFilterUrlParams({
        paymentStatus: InvoicePaymentStatusTypeEnum.Succeeded,
        status: InvoiceStatusTypeEnum.Finalized,
      }),
    ).toEqual(expectedSearchParams)

    const succeededSearchParams = new Map(
      new URLSearchParams(`?${expectedSearchParams}`).entries(),
    ) as unknown as URLSearchParams

    expect(
      isSucceededUrlParams({ prefix: FILTER_PREFIX, searchParams: succeededSearchParams }),
    ).toBe(true)
  })
  it('should return search params with initial static filters', () => {
    const { result } = renderHook(() => useFilters(), {
      wrapper: ({ children }) =>
        wrapper({ children, withStaticFilters: true, withStaticQuickFilters: false }),
    })

    const expectedSearchParams = 'f_currency=eur&f_paymentStatus=succeeded&f_status=finalized'

    expect(
      result.current.buildQuickFilterUrlParams({
        paymentStatus: InvoicePaymentStatusTypeEnum.Succeeded,
        status: InvoiceStatusTypeEnum.Finalized,
      }),
    ).toEqual(expectedSearchParams)

    const succeededSearchParams = new Map(
      new URLSearchParams(`?${expectedSearchParams}`).entries(),
    ) as unknown as URLSearchParams

    expect(
      isSucceededUrlParams({ prefix: FILTER_PREFIX, searchParams: succeededSearchParams }),
    ).toBe(true)
  })
})

describe('voided', () => {
  it('should return search params without initial static filters', () => {
    const { result } = renderHook(() => useFilters(), {
      wrapper: ({ children }) =>
        wrapper({ children, withStaticFilters: false, withStaticQuickFilters: false }),
    })

    const expectedSearchParams = 'f_status=voided'

    expect(
      result.current.buildQuickFilterUrlParams({
        status: InvoiceStatusTypeEnum.Voided,
      }),
    ).toEqual(expectedSearchParams)

    const voidedSearchParams = new Map(
      new URLSearchParams(`?${expectedSearchParams}`).entries(),
    ) as unknown as URLSearchParams

    expect(isVoidedUrlParams({ prefix: FILTER_PREFIX, searchParams: voidedSearchParams })).toBe(
      true,
    )
  })
  it('should return search params with initial static filters', () => {
    const { result } = renderHook(() => useFilters(), {
      wrapper: ({ children }) =>
        wrapper({ children, withStaticFilters: true, withStaticQuickFilters: false }),
    })

    const expectedSearchParams = 'f_currency=eur&f_status=voided'

    expect(
      result.current.buildQuickFilterUrlParams({
        status: InvoiceStatusTypeEnum.Voided,
      }),
    ).toEqual(expectedSearchParams)

    const voidedSearchParams = new Map(
      new URLSearchParams(`?${expectedSearchParams}`).entries(),
    ) as unknown as URLSearchParams

    expect(isVoidedUrlParams({ prefix: FILTER_PREFIX, searchParams: voidedSearchParams })).toBe(
      true,
    )
  })
})

describe('payment dispute lost', () => {
  it('should return search params without initial static filters', () => {
    const { result } = renderHook(() => useFilters(), {
      wrapper: ({ children }) =>
        wrapper({ children, withStaticFilters: false, withStaticQuickFilters: false }),
    })

    const expectedSearchParams = 'f_paymentDisputeLost=true'

    expect(
      result.current.buildQuickFilterUrlParams({
        paymentDisputeLost: true,
      }),
    ).toEqual(expectedSearchParams)

    const paymentDisputeLostSearchParams = new Map(
      new URLSearchParams(`?${expectedSearchParams}`).entries(),
    ) as unknown as URLSearchParams

    expect(
      isPaymentDisputeLostUrlParams({
        prefix: FILTER_PREFIX,
        searchParams: paymentDisputeLostSearchParams,
      }),
    ).toBe(true)
  })
  it('should return search params with initial static filters', () => {
    const { result } = renderHook(() => useFilters(), {
      wrapper: ({ children }) =>
        wrapper({ children, withStaticFilters: true, withStaticQuickFilters: false }),
    })

    const expectedSearchParams = 'f_currency=eur&f_paymentDisputeLost=true'

    expect(
      result.current.buildQuickFilterUrlParams({
        paymentDisputeLost: true,
      }),
    ).toEqual(expectedSearchParams)

    const paymentDisputeLostSearchParams = new Map(
      new URLSearchParams(`?${expectedSearchParams}`).entries(),
    ) as unknown as URLSearchParams

    expect(
      isPaymentDisputeLostUrlParams({
        prefix: FILTER_PREFIX,
        searchParams: paymentDisputeLostSearchParams,
      }),
    ).toBe(true)
  })
})

describe('selectTimeGranularity', () => {
  it('should update timeGranularity with no static filters', () => {
    const { result } = renderHook(() => useFilters(), {
      wrapper: ({ children }) =>
        wrapper({ children, withStaticFilters: false, withStaticQuickFilters: false }),
    })

    expect(result.current.selectTimeGranularity(TimeGranularityEnum.Daily)).toEqual(
      'f_timeGranularity=daily',
    )

    expect(result.current.selectTimeGranularity(TimeGranularityEnum.Weekly)).toEqual(
      'f_timeGranularity=weekly',
    )

    expect(result.current.selectTimeGranularity(TimeGranularityEnum.Monthly)).toEqual(
      'f_timeGranularity=monthly',
    )
  })

  it('should update timeGranularity with static filters', () => {
    const { result } = renderHook(() => useFilters(), {
      wrapper: ({ children }) =>
        wrapper({ children, withStaticFilters: true, withStaticQuickFilters: true }),
    })

    expect(result.current.selectTimeGranularity(TimeGranularityEnum.Monthly)).toEqual(
      'f_timeGranularity=monthly',
    )
  })

  it('should not modify ISO date with timezone when updating timeGranularity', () => {
    const isoDateWithTimezone = '2023-04-01T00:00:00.000Z'
    const initialSearchParams = `${FILTER_PREFIX}_date=${encodeURIComponent(isoDateWithTimezone)}`

    const { result } = renderHook(() => useFilters(), {
      wrapper: ({ children }) =>
        wrapper({
          children,
          withStaticFilters: false,
          withStaticQuickFilters: false,
          initialSearchParams,
        }),
    })

    // When updating the time granularity
    const updatedParams = result.current.selectTimeGranularity(TimeGranularityEnum.Weekly)

    // The date parameter should still be present and unchanged
    expect(updatedParams).toContain(
      `${FILTER_PREFIX}_date=${encodeURIComponent(isoDateWithTimezone)}`,
    )

    // And the time granularity should be updated
    expect(updatedParams).toContain(`${FILTER_PREFIX}_timeGranularity=weekly`)
  })
})
