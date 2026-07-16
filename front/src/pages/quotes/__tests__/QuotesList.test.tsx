import { screen } from '@testing-library/react'

import { filterDataInlineSeparator } from '~/components/designSystem/Filters/types'
import { OrderTypeEnum, StatusEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { useQuotes } from '../hooks/useQuotes'
import QuotesList from '../QuotesList'

// Mock IntersectionObserver
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

jest.mock('../hooks/useQuotes', () => ({
  useQuotes: jest.fn(),
}))

const mockUseQuotes = useQuotes as jest.MockedFunction<typeof useQuotes>

const mockQuotes = [
  {
    id: 'quote-1',
    number: 'QT-2026-0042',
    versions: [{ id: 'version-1', status: StatusEnum.Draft, version: 2 }],
    orderType: OrderTypeEnum.SubscriptionAmendment,
    createdAt: '2026-04-09T15:00:00Z',
    customer: { id: 'customer-001', name: 'Acme Corp', displayName: 'Acme Corp' },
  },
  {
    id: 'quote-2',
    number: 'QT-2026-0038',
    versions: [{ id: 'version-2', status: StatusEnum.Approved, version: 2 }],
    orderType: OrderTypeEnum.SubscriptionCreation,
    createdAt: '2026-04-01T09:00:00Z',
    customer: { id: 'customer-002', name: 'Globex Inc', displayName: 'Globex Inc' },
  },
  {
    id: 'quote-3',
    number: 'QT-2026-0015',
    versions: [{ id: 'version-3', status: StatusEnum.Voided, version: 1 }],
    orderType: OrderTypeEnum.OneOff,
    createdAt: '2026-03-10T08:00:00Z',
    customer: { id: 'customer-003', name: 'Wayne Enterprises', displayName: 'Wayne Enterprises' },
  },
]

describe('QuotesList', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockUseQuotes.mockReturnValue({
      quotes: mockQuotes,
      loading: false,
      error: undefined,
      fetchMore: jest.fn(),
      metadata: { currentPage: 1, totalPages: 1, totalCount: 3 },
    })
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN quotes are loaded', () => {
      it('THEN should call useQuotes with no arguments', () => {
        render(<QuotesList />)

        expect(mockUseQuotes).toHaveBeenCalled()
      })

      it('THEN should render the quotes table with rows', () => {
        render(<QuotesList />)

        expect(screen.getByTestId('table-row-0')).toBeInTheDocument()
        expect(screen.getByTestId('table-row-1')).toBeInTheDocument()
        expect(screen.getByTestId('table-row-2')).toBeInTheDocument()
      })

      it('THEN should display quote numbers', () => {
        render(<QuotesList />)

        expect(screen.getByText('QT-2026-0042')).toBeInTheDocument()
        expect(screen.getByText('QT-2026-0038')).toBeInTheDocument()
        expect(screen.getByText('QT-2026-0015')).toBeInTheDocument()
      })

      it('THEN should display customer names', () => {
        render(<QuotesList />)

        expect(screen.getByText('Acme Corp')).toBeInTheDocument()
        expect(screen.getByText('Globex Inc')).toBeInTheDocument()
        expect(screen.getByText('Wayne Enterprises')).toBeInTheDocument()
      })

      it('THEN should display status badges', () => {
        render(<QuotesList />)

        const statusBadges = screen.getAllByTestId('status')

        expect(statusBadges.length).toBeGreaterThan(0)
      })

      it('THEN should display version numbers', () => {
        render(<QuotesList />)

        expect(screen.getAllByText('2').length).toBeGreaterThan(0)
        expect(screen.getAllByText('1').length).toBeGreaterThan(0)
      })
    })

    describe('WHEN quotes are loading', () => {
      it('THEN should show the table in loading state', () => {
        mockUseQuotes.mockReturnValue({
          quotes: [],
          loading: true,
          error: undefined,
          fetchMore: jest.fn(),
          metadata: undefined,
        })

        render(<QuotesList />)

        expect(screen.getByTestId('table-quotes-list')).toBeInTheDocument()
      })
    })

    describe('WHEN there are no quotes', () => {
      it('THEN should show empty state', () => {
        mockUseQuotes.mockReturnValue({
          quotes: [],
          loading: false,
          error: undefined,
          fetchMore: jest.fn(),
          metadata: undefined,
        })

        render(<QuotesList />)

        expect(screen.queryByTestId('table-row-0')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN URL search params contain quote filters', () => {
    afterEach(() => {
      window.history.replaceState({}, '', '/')
    })

    describe('WHEN quoteStatus filter is set', () => {
      it('THEN should pass statuses to useQuotes', () => {
        window.history.replaceState({}, '', '?qu_quoteStatus=draft%2Capproved')

        render(<QuotesList />)

        expect(mockUseQuotes).toHaveBeenCalledWith(
          expect.objectContaining({
            statuses: ['draft', 'approved'],
          }),
        )
      })
    })

    describe('WHEN multipleCustomers filter is set', () => {
      it('THEN should pass customer ids to useQuotes', () => {
        const paramValue = `cust-1${filterDataInlineSeparator}Acme Corp`

        window.history.replaceState(
          {},
          '',
          `?qu_multipleCustomers=${encodeURIComponent(paramValue)}`,
        )

        render(<QuotesList />)

        expect(mockUseQuotes).toHaveBeenCalledWith(
          expect.objectContaining({
            customers: ['cust-1'],
          }),
        )
      })
    })

    describe('WHEN no quote filters are set', () => {
      it('THEN should call useQuotes without filter properties', () => {
        window.history.replaceState({}, '', '/')

        render(<QuotesList />)

        expect(mockUseQuotes).toHaveBeenCalledWith(
          expect.not.objectContaining({
            statuses: expect.anything(),
          }),
        )
      })
    })
  })
})
