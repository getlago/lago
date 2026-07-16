import { render } from '~/test-utils'

import { QuotesSectionTable } from '../QuotesSectionTable'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

const mockTableProps: { current?: Record<string, unknown> } = {}

jest.mock('~/components/designSystem/Table/Table', () => ({
  Table: (props: Record<string, unknown>) => {
    mockTableProps.current = props
    return null
  },
}))

const mockInfiniteScrollProps: { current?: Record<string, unknown> } = {}

jest.mock('~/components/designSystem/InfiniteScroll', () => ({
  InfiniteScroll: (props: { children: React.ReactNode; onBottom: () => void }) => {
    mockInfiniteScrollProps.current = props
    return props.children
  },
}))

type Row = { id: string; number: string }

const baseProps = {
  name: 'orders-list',
  data: [{ id: '1', number: 'OF-1' }] as Row[],
  isLoading: false,
  hasError: false,
  columns: [],
  emptyState: { title: 'empty-title', subtitle: 'empty-subtitle' },
}

beforeEach(() => {
  mockTableProps.current = undefined
  mockInfiniteScrollProps.current = undefined
})

describe('QuotesSectionTable', () => {
  it('passes name, containerSize and emptyState placeholder through to Table', () => {
    const fetchMore = jest.fn()

    render(
      <QuotesSectionTable<Row>
        {...baseProps}
        metadata={{ currentPage: 1, totalPages: 2 }}
        fetchMore={fetchMore}
      />,
    )

    expect(mockTableProps.current?.name).toBe('orders-list')
    expect(mockTableProps.current?.containerSize).toBe(0)
    expect(mockTableProps.current?.placeholder).toEqual({
      emptyState: { title: 'empty-title', subtitle: 'empty-subtitle' },
    })
  })

  it('onBottom calls fetchMore with the next page when more pages exist', () => {
    const fetchMore = jest.fn()

    render(
      <QuotesSectionTable<Row>
        {...baseProps}
        metadata={{ currentPage: 1, totalPages: 3 }}
        fetchMore={fetchMore}
      />,
    )
    ;(mockInfiniteScrollProps.current?.onBottom as () => void)()
    expect(fetchMore).toHaveBeenCalledWith({ variables: { page: 2 } })
  })

  it('onBottom is a no-op on the last page', () => {
    const fetchMore = jest.fn()

    render(
      <QuotesSectionTable<Row>
        {...baseProps}
        metadata={{ currentPage: 3, totalPages: 3 }}
        fetchMore={fetchMore}
      />,
    )
    ;(mockInfiniteScrollProps.current?.onBottom as () => void)()
    expect(fetchMore).not.toHaveBeenCalled()
  })

  it('onBottom is a no-op while loading', () => {
    const fetchMore = jest.fn()

    render(
      <QuotesSectionTable<Row>
        {...baseProps}
        isLoading
        metadata={{ currentPage: 1, totalPages: 3 }}
        fetchMore={fetchMore}
      />,
    )
    ;(mockInfiniteScrollProps.current?.onBottom as () => void)()
    expect(fetchMore).not.toHaveBeenCalled()
  })

  it('maps getActions results into action items and returns null when empty', () => {
    const onAction = jest.fn()
    const getActions = jest.fn((row: Row) =>
      row.number === 'OF-1' ? [{ icon: 'stop' as const, label: 'Void', onAction }] : [],
    )

    render(
      <QuotesSectionTable<Row>
        {...baseProps}
        metadata={{ currentPage: 1, totalPages: 1 }}
        fetchMore={jest.fn()}
        getActions={getActions}
      />,
    )

    const actionColumn = mockTableProps.current?.actionColumn as (row: Row) => unknown
    const items = actionColumn({ id: '1', number: 'OF-1' }) as Array<{
      startIcon: string
      title: string
      onAction: () => void
    }>

    expect(items).toHaveLength(1)
    expect(items[0]).toMatchObject({ startIcon: 'stop', title: 'Void' })
    items[0].onAction()
    expect(onAction).toHaveBeenCalled()

    expect(actionColumn({ id: '2', number: 'OTHER' })).toBeNull()
  })

  it('does not set actionColumn/actionColumnTooltip when getActions is not provided', () => {
    render(
      <QuotesSectionTable<Row>
        {...baseProps}
        metadata={{ currentPage: 1, totalPages: 1 }}
        fetchMore={jest.fn()}
      />,
    )

    expect(mockTableProps.current?.actionColumn).toBeUndefined()
    expect(mockTableProps.current?.actionColumnTooltip).toBeUndefined()
  })
})
