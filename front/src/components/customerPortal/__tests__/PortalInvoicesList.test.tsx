import { ApolloError } from '@apollo/client'
import { screen } from '@testing-library/react'

import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import PortalInvoicesList, {
  PORTAL_INVOICES_LIST_CONTENT_TEST_ID,
  PORTAL_INVOICES_LIST_ERROR_TEST_ID,
  PORTAL_INVOICES_LIST_LOAD_MORE_TEST_ID,
  PORTAL_INVOICES_LIST_OVERDUE_TEST_ID,
  PORTAL_INVOICES_LIST_TOTALS_TEST_ID,
} from '../PortalInvoicesList'

const mockUseCustomerPortalTranslate = jest.fn()
const mockUseCustomerPortalData = jest.fn()
const mockGetInvoices = jest.fn()
const mockGetOverdueBalance = jest.fn()
const mockGetInvoicesCollection = jest.fn()
const mockFetchMore = jest.fn()
const mockRefetch = jest.fn()
const mockDownloadInvoice = jest.fn()

const mockUseCustomerPortalInvoicesLazyQuery = jest.fn()
const mockUseGetOverdueBalancesLazyQuery = jest.fn()
const mockUseGetInvoicesCollectionLazyQuery = jest.fn()
const mockUseDownloadMutation = jest.fn()

jest.mock('~/components/customerPortal/common/useCustomerPortalTranslate', () => ({
  __esModule: true,
  default: () => mockUseCustomerPortalTranslate(),
}))

jest.mock('~/components/customerPortal/common/hooks/useCustomerPortalData', () => ({
  useCustomerPortalData: () => mockUseCustomerPortalData(),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  envGlobalVar: () => ({ disablePdfGeneration: false }),
}))

jest.mock('~/hooks/useDownloadFile', () => ({
  useDownloadFile: () => ({ handleDownloadFile: jest.fn() }),
}))

jest.mock('~/hooks/useDebouncedSearch', () => ({
  useDebouncedSearch: (fn: (...args: unknown[]) => unknown, loading: boolean) => ({
    debouncedSearch: jest.fn(),
    isLoading: loading,
  }),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useCustomerPortalInvoicesLazyQuery: (...args: unknown[]) =>
    mockUseCustomerPortalInvoicesLazyQuery(...args),
  useGetCustomerPortalOverdueBalancesLazyQuery: (...args: unknown[]) =>
    mockUseGetOverdueBalancesLazyQuery(...args),
  useGetCustomerPortalInvoicesCollectionLazyQuery: (...args: unknown[]) =>
    mockUseGetInvoicesCollectionLazyQuery(...args),
  useDownloadCustomerPortalInvoiceMutation: (...args: unknown[]) =>
    mockUseDownloadMutation(...args),
}))

jest.mock('~/components/customerPortal/common/SectionError', () => ({
  __esModule: true,
  default: () => <div data-test="section-error">Error</div>,
}))

jest.mock('~/components/customerPortal/common/SectionTitle', () => ({
  __esModule: true,
  default: ({ loading }: { title: string; loading?: boolean }) => (
    <div data-test="section-title">{loading && <span data-test="section-title-loading" />}</div>
  ),
}))

jest.mock('~/components/customerPortal/common/SectionLoading', () => ({
  LoaderInvoicesListTotal: () => <div data-test="loading-total">Loading</div>,
}))

jest.mock('~/components/SearchInput', () => ({
  SearchInput: ({
    onChange,
    placeholder,
  }: {
    onChange: (value: string) => void
    placeholder: string
  }) => (
    <input
      data-test="search-input"
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
    />
  ),
}))

jest.mock('~/components/designSystem/Table/Table', () => ({
  Table: ({ data, isLoading, name }: { data: unknown[]; isLoading: boolean; name: string }) => (
    <div data-test={`table-${name}`}>
      {isLoading && <span data-test="table-loading">Loading</span>}
      {data.map((item: any) => (
        <div key={item.id} data-test={`table-row-${item.id}`}>
          {item.number}
        </div>
      ))}
    </div>
  ),
}))

jest.mock('~/core/formats/intlFormatNumber', () => ({
  intlFormatNumber: jest.fn(() => '$100.00'),
}))

jest.mock('~/core/serializers/serializeAmount', () => ({
  deserializeAmount: jest.fn((cents: number) => cents / 100),
}))

const setupDefaultMocks = () => {
  mockUseCustomerPortalTranslate.mockReturnValue({
    translate: (key: string) => key,
    documentLocale: 'en',
  })

  mockUseCustomerPortalData.mockReturnValue({
    data: {
      customerPortalUser: {
        currency: CurrencyEnum.Usd,
      },
    },
  })

  mockUseCustomerPortalInvoicesLazyQuery.mockReturnValue([
    mockGetInvoices,
    {
      data: {
        customerPortalInvoices: {
          metadata: {
            currentPage: 1,
            totalPages: 1,
            totalCount: 2,
          },
          collection: [
            {
              id: 'invoice-1',
              number: 'INV-001',
              paymentStatus: 'succeeded',
              paymentOverdue: false,
              paymentDisputeLostAt: null,
              issuingDate: '2024-01-15',
              totalAmountCents: 10000,
              totalDueAmountCents: 0,
              currency: CurrencyEnum.Usd,
              invoiceType: 'subscription',
            },
            {
              id: 'invoice-2',
              number: 'INV-002',
              paymentStatus: 'pending',
              paymentOverdue: false,
              paymentDisputeLostAt: null,
              issuingDate: '2024-02-15',
              totalAmountCents: 20000,
              totalDueAmountCents: 20000,
              currency: CurrencyEnum.Usd,
              invoiceType: 'subscription',
            },
          ],
        },
      },
      loading: false,
      error: undefined,
      fetchMore: mockFetchMore,
      variables: {},
      refetch: mockRefetch,
    },
  ])

  mockUseGetOverdueBalancesLazyQuery.mockReturnValue([
    mockGetOverdueBalance,
    {
      data: undefined,
      loading: false,
      error: undefined,
    },
  ])

  mockUseGetInvoicesCollectionLazyQuery.mockReturnValue([
    mockGetInvoicesCollection,
    {
      data: undefined,
      loading: false,
      error: undefined,
    },
  ])

  mockUseDownloadMutation.mockReturnValue([mockDownloadInvoice])
}

describe('PortalInvoicesList', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    setupDefaultMocks()
  })

  describe('Error state', () => {
    it('GIVEN the invoices query has an error THEN should render the error state', () => {
      // GIVEN
      const apolloError = new ApolloError({ errorMessage: 'Network error' })

      mockUseCustomerPortalInvoicesLazyQuery.mockReturnValue([
        mockGetInvoices,
        {
          data: undefined,
          loading: false,
          error: apolloError,
          fetchMore: mockFetchMore,
          variables: {},
          refetch: mockRefetch,
        },
      ])

      // WHEN
      render(<PortalInvoicesList />)

      // THEN
      expect(screen.getByTestId(PORTAL_INVOICES_LIST_ERROR_TEST_ID)).toBeInTheDocument()
      expect(screen.getByTestId('section-error')).toBeInTheDocument()
      expect(screen.queryByTestId(PORTAL_INVOICES_LIST_CONTENT_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('Content rendering', () => {
    it('GIVEN data is loaded with invoices THEN should render content', () => {
      // GIVEN - default mocks have invoices data

      // WHEN
      render(<PortalInvoicesList />)

      // THEN
      expect(screen.getByTestId(PORTAL_INVOICES_LIST_CONTENT_TEST_ID)).toBeInTheDocument()
      expect(screen.queryByTestId(PORTAL_INVOICES_LIST_ERROR_TEST_ID)).not.toBeInTheDocument()
    })

    it('GIVEN invoices and overdue data are loaded THEN should render totals section', () => {
      // GIVEN
      mockUseGetOverdueBalancesLazyQuery.mockReturnValue([
        mockGetOverdueBalance,
        {
          data: {
            customerPortalOverdueBalances: {
              collection: [
                {
                  amountCents: 5000,
                  currency: CurrencyEnum.Usd,
                  lagoInvoiceIds: ['invoice-1'],
                },
              ],
            },
          },
          loading: false,
          error: undefined,
        },
      ])

      mockUseGetInvoicesCollectionLazyQuery.mockReturnValue([
        mockGetInvoicesCollection,
        {
          data: {
            customerPortalInvoiceCollections: {
              collection: [
                {
                  amountCents: 30000,
                  invoicesCount: 2,
                  currency: CurrencyEnum.Usd,
                },
              ],
            },
          },
          loading: false,
          error: undefined,
        },
      ])

      // WHEN
      render(<PortalInvoicesList />)

      // THEN
      expect(screen.getByTestId(PORTAL_INVOICES_LIST_TOTALS_TEST_ID)).toBeInTheDocument()
      expect(screen.getByTestId(PORTAL_INVOICES_LIST_OVERDUE_TEST_ID)).toBeInTheDocument()
    })
  })

  describe('Loading states', () => {
    it('GIVEN overdue data is loading THEN should show loading for overdue', () => {
      // GIVEN
      mockUseGetOverdueBalancesLazyQuery.mockReturnValue([
        mockGetOverdueBalance,
        {
          data: undefined,
          loading: true,
          error: undefined,
        },
      ])

      // WHEN
      render(<PortalInvoicesList />)

      // THEN
      const overdueSection = screen.getByTestId(PORTAL_INVOICES_LIST_OVERDUE_TEST_ID)

      expect(overdueSection).toBeInTheDocument()
      expect(overdueSection.querySelector('[data-test="loading-total"]')).toBeInTheDocument()
    })

    it('GIVEN invoices collection is loading THEN should show loading for totals', () => {
      // GIVEN
      mockUseGetInvoicesCollectionLazyQuery.mockReturnValue([
        mockGetInvoicesCollection,
        {
          data: undefined,
          loading: true,
          error: undefined,
        },
      ])

      // WHEN
      render(<PortalInvoicesList />)

      // THEN
      const totalsSection = screen.getByTestId(PORTAL_INVOICES_LIST_TOTALS_TEST_ID)

      expect(totalsSection).toBeInTheDocument()
      expect(totalsSection.querySelector('[data-test="loading-total"]')).toBeInTheDocument()
    })
  })

  describe('Empty state', () => {
    it('GIVEN there are no invoices and no search term THEN should not render table section', () => {
      // GIVEN
      mockUseCustomerPortalInvoicesLazyQuery.mockReturnValue([
        mockGetInvoices,
        {
          data: {
            customerPortalInvoices: {
              metadata: {
                currentPage: 1,
                totalPages: 0,
                totalCount: 0,
              },
              collection: [],
            },
          },
          loading: false,
          error: undefined,
          fetchMore: mockFetchMore,
          variables: {},
          refetch: mockRefetch,
        },
      ])

      // WHEN
      render(<PortalInvoicesList />)

      // THEN
      expect(screen.queryByTestId('table-portal-invoice')).not.toBeInTheDocument()
    })
  })

  describe('Pagination', () => {
    it('GIVEN there are more pages THEN should show load more button', () => {
      // GIVEN
      mockUseCustomerPortalInvoicesLazyQuery.mockReturnValue([
        mockGetInvoices,
        {
          data: {
            customerPortalInvoices: {
              metadata: {
                currentPage: 1,
                totalPages: 3,
                totalCount: 20,
              },
              collection: [
                {
                  id: 'invoice-1',
                  number: 'INV-001',
                  paymentStatus: 'succeeded',
                  paymentOverdue: false,
                  paymentDisputeLostAt: null,
                  issuingDate: '2024-01-15',
                  totalAmountCents: 10000,
                  totalDueAmountCents: 0,
                  currency: CurrencyEnum.Usd,
                  invoiceType: 'subscription',
                },
              ],
            },
          },
          loading: false,
          error: undefined,
          fetchMore: mockFetchMore,
          variables: {},
          refetch: mockRefetch,
        },
      ])

      // WHEN
      render(<PortalInvoicesList />)

      // THEN
      expect(screen.getByTestId(PORTAL_INVOICES_LIST_LOAD_MORE_TEST_ID)).toBeInTheDocument()
    })

    it('GIVEN there are no more pages THEN should not show load more button', () => {
      // GIVEN - default mocks have currentPage=1, totalPages=1

      // WHEN
      render(<PortalInvoicesList />)

      // THEN
      expect(screen.queryByTestId(PORTAL_INVOICES_LIST_LOAD_MORE_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('Lazy queries on mount', () => {
    it('GIVEN lazy queries THEN should call getOverdueBalance and getInvoicesCollection on mount', () => {
      // GIVEN - default mocks

      // WHEN
      render(<PortalInvoicesList />)

      // THEN
      expect(mockGetOverdueBalance).toHaveBeenCalled()
      expect(mockGetInvoicesCollection).toHaveBeenCalled()
    })
  })
})
