import { render, renderHook, screen } from '@testing-library/react'

import { QuoteListItemFragment } from '~/generated/graphql'

import { useSharedColumns } from '../sharedColumns'

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

const row = {
  id: 'q-1',
  number: 'QUO-001',
  createdAt: '2026-04-10T10:00:00Z',
  customer: { id: 'c-1', displayName: 'Acme Corp' },
} as unknown as QuoteListItemFragment

describe('useSharedColumns', () => {
  it('getNumberColumn returns a number column titled by the given key', () => {
    const { result } = renderHook(() => useSharedColumns())
    const column = result.current.getNumberColumn<QuoteListItemFragment>('text_number_key')

    expect(column.key).toBe('number')
    expect(column.title).toBe('text_number_key')

    render(<>{column.content(row)}</>)
    expect(screen.getByText('QUO-001')).toBeInTheDocument()
  })

  it('getCustomerColumn renders customer.displayName', () => {
    const { result } = renderHook(() => useSharedColumns())
    const column = result.current.getCustomerColumn<QuoteListItemFragment>()

    expect(column.key).toBe('customer.displayName')

    render(<>{column.content(row)}</>)
    expect(screen.getByText('Acme Corp')).toBeInTheDocument()
  })

  it('getCreatedAtColumn formats the date and honors the minWidth arg', () => {
    const { result } = renderHook(() => useSharedColumns())
    const column = result.current.getCreatedAtColumn<QuoteListItemFragment>('text_created_key', 120)

    expect(column.key).toBe('createdAt')
    expect(column.minWidth).toBe(120)

    render(<>{column.content(row)}</>)
    expect(screen.getByText('4/10/2026')).toBeInTheDocument()
  })
})
