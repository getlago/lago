import { renderHook, screen } from '@testing-library/react'

import { OrderFormStatusEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { useOrderFormsColumns } from '../useOrderFormsColumns'

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

const orderForm = {
  id: 'of-1',
  number: 'OF-001',
  status: OrderFormStatusEnum.Generated,
  createdAt: '2026-04-10T10:00:00Z',
  customer: { id: 'c-1', displayName: 'Test Customer' },
  quote: { id: 'q-1', number: 'QUO-001', currentVersion: { id: 'qv-1', version: 1 } },
} as never

describe('useOrderFormsColumns', () => {
  it('returns columns in order with the corrected "Order form number" title', () => {
    const { result } = renderHook(() => useOrderFormsColumns())

    expect(result.current.map((c) => c.key)).toEqual([
      'number',
      'customer.displayName',
      'status',
      'quote.number',
      'createdAt',
    ])
    // FIX: was 'text_1775746196826pyjlfqx3anr' ("Quote number")
    expect(result.current[0].title).toBe('text_1781624189693d7zcv2vog4c')
  })

  it('status column renders a Status badge', () => {
    const { result } = renderHook(() => useOrderFormsColumns())
    const statusColumn = result.current[2]

    expect(statusColumn.key).toBe('status')
    expect(statusColumn.minWidth).toBe(100)

    render(<>{statusColumn.content(orderForm)}</>)
    expect(screen.getByTestId('status')).toBeInTheDocument()
  })

  it('createdAt column has minWidth 120 and formats the date', () => {
    const { result } = renderHook(() => useOrderFormsColumns())
    const createdAtColumn = result.current[4]

    expect(createdAtColumn.key).toBe('createdAt')
    expect(createdAtColumn.minWidth).toBe(120)

    render(<>{createdAtColumn.content(orderForm)}</>)
    expect(screen.getByText('4/10/2026')).toBeInTheDocument()
  })
})
