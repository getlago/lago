import { screen } from '@testing-library/react'

import { OrderExecutionModeEnum, OrderStatusEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { useOrders } from '../hooks/useOrders'
import OrdersList from '../OrdersList'

const mockIntersectionObserver = jest.fn()

mockIntersectionObserver.mockReturnValue({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
})

globalThis.IntersectionObserver = mockIntersectionObserver

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    intlFormatDateTimeOrgaTZ: (date: string) => ({
      date: new Date(date).toLocaleDateString('en-US'),
    }),
  }),
}))

jest.mock('../hooks/useOrders', () => ({
  useOrders: jest.fn(),
}))

jest.mock('~/pages/quotes/common/QuotePdfProvider', () => ({
  useDownloadQuotePdf: () => ({ download: jest.fn() }),
}))

const mockUseOrders = useOrders as jest.MockedFunction<typeof useOrders>

const mockOrders = [
  {
    id: 'order-1',
    number: 'ORD-2026-0001',
    status: OrderStatusEnum.Executed,
    executionMode: OrderExecutionModeEnum.ExecuteInLago,
    executedAt: '2026-04-10T10:00:00Z',
    customer: { id: 'customer-001', displayName: 'Acme Corp' },
    orderForm: {
      id: 'of-1',
      number: 'OF-2026-0001',
      quote: {
        id: 'q-1',
        number: 'QUO-001',
        images: {},
        currentVersion: { id: 'qv-1', version: 1, content: '# Hello World', mentionVariables: {} },
      },
    },
  },
  {
    id: 'order-2',
    number: 'ORD-2026-0002',
    status: OrderStatusEnum.Created,
    executionMode: null,
    executedAt: null,
    customer: { id: 'customer-002', displayName: 'Globex Corp' },
    orderForm: {
      id: 'of-2',
      number: 'OF-2026-0002',
      quote: {
        id: 'q-2',
        number: 'QUO-002',
        images: {},
        currentVersion: { id: 'qv-2', version: 1, content: '# Hello World', mentionVariables: {} },
      },
    },
  },
]

describe('OrdersList', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockUseOrders.mockReturnValue({
      orders: mockOrders,
      loading: false,
      error: undefined,
      fetchMore: jest.fn(),
      metadata: { currentPage: 1, totalPages: 1, totalCount: 2 },
    })
  })

  describe('GIVEN the component is rendered on the list page (no quoteNumber)', () => {
    it('THEN should render a row per order', () => {
      render(<OrdersList />)

      expect(screen.getByTestId('table-row-0')).toBeInTheDocument()
      expect(screen.getByTestId('table-row-1')).toBeInTheDocument()
    })

    it('THEN should display order numbers', () => {
      render(<OrdersList />)

      expect(screen.getByText('ORD-2026-0001')).toBeInTheDocument()
      expect(screen.getByText('ORD-2026-0002')).toBeInTheDocument()
    })

    it('THEN should display status badges', () => {
      render(<OrdersList />)

      expect(screen.getAllByTestId('status')).toHaveLength(2)
    })

    it('THEN should display the source quote column', () => {
      render(<OrdersList />)

      expect(screen.getByText('QUO-001')).toBeInTheDocument()
    })

    it('THEN should display the order form numbers', () => {
      render(<OrdersList />)

      expect(screen.getByText('OF-2026-0001')).toBeInTheDocument()
    })

    it('THEN should render a dash for missing execution mode and date', () => {
      render(<OrdersList />)

      expect(screen.getAllByText('-').length).toBeGreaterThanOrEqual(2)
    })
  })

  describe('GIVEN the component is rendered in quote details (quoteNumber set)', () => {
    it('THEN should request orders scoped to the quote', () => {
      render(<OrdersList quoteNumber="QUO-001" />)

      expect(mockUseOrders).toHaveBeenCalledWith({ quoteNumber: ['QUO-001'] })
    })

    it('THEN should NOT display the source quote column', () => {
      render(<OrdersList quoteNumber="QUO-001" />)

      expect(screen.queryByText('QUO-001')).not.toBeInTheDocument()
    })

    it('THEN should still display the order form column', () => {
      render(<OrdersList quoteNumber="QUO-001" />)

      expect(screen.getByText('OF-2026-0001')).toBeInTheDocument()
    })
  })

  describe('GIVEN there are no orders', () => {
    it('THEN should not render any rows', () => {
      mockUseOrders.mockReturnValue({
        orders: [],
        loading: false,
        error: undefined,
        fetchMore: jest.fn(),
        metadata: undefined,
      })

      render(<OrdersList />)

      expect(screen.queryByTestId('table-row-0')).not.toBeInTheDocument()
    })
  })

  describe('GIVEN orders are loading', () => {
    it('THEN should render the table in loading state', () => {
      mockUseOrders.mockReturnValue({
        orders: [],
        loading: true,
        error: undefined,
        fetchMore: jest.fn(),
        metadata: undefined,
      })

      render(<OrdersList />)

      expect(screen.getByTestId('table-orders-list')).toBeInTheDocument()
    })
  })

  it('passes URL filters to useOrders when no quoteNumber prop is given', () => {
    window.history.pushState({}, '', '/orders?or_orderStatus=executed')
    try {
      render(<OrdersList />)
      expect(mockUseOrders).toHaveBeenCalledWith(expect.objectContaining({ status: ['executed'] }))
    } finally {
      window.history.pushState({}, '', '/')
    }
  })
})
