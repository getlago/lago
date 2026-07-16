import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import WalletSection, {
  WALLET_SECTION_CONTENT_TEST_ID,
  WALLET_SECTION_ERROR_TEST_ID,
  WALLET_SECTION_LOAD_MORE_TEST_ID,
  WALLET_SECTION_VIEW_BUTTON_TEST_ID,
  WALLET_SECTION_WALLET_ITEM_TEST_ID,
} from '../WalletSection'

const mockUseCustomerPortalData = jest.fn()
const mockUseCustomerPortalTranslate = jest.fn()
const mockUseGetPortalWalletsQuery = jest.fn()

jest.mock('~/components/customerPortal/common/hooks/useCustomerPortalData', () => ({
  useCustomerPortalData: () => mockUseCustomerPortalData(),
}))

jest.mock('~/components/customerPortal/common/useCustomerPortalTranslate', () => ({
  __esModule: true,
  default: () => mockUseCustomerPortalTranslate(),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetPortalWalletsQuery: () => mockUseGetPortalWalletsQuery(),
}))

jest.mock('~/components/customerPortal/common/SectionError', () => ({
  __esModule: true,
  default: ({ refresh }: { refresh?: () => void }) => (
    <div data-test="section-error">
      <button data-test="section-error-refresh" onClick={refresh}>
        Refresh
      </button>
    </div>
  ),
}))

jest.mock('~/components/customerPortal/common/SectionTitle', () => ({
  __esModule: true,
  default: ({ loading }: { title: string; loading?: boolean }) => (
    <div data-test="section-title">
      {loading && <span data-test="section-title-loading">Loading</span>}
    </div>
  ),
}))

jest.mock('~/components/customerPortal/common/SectionLoading', () => ({
  LoaderWalletSection: () => <div data-test="loading-skeleton">Loading</div>,
}))

jest.mock('~/core/formats/intlFormatNumber', () => ({
  intlFormatNumber: jest.fn(() => '$100.00'),
}))

jest.mock('~/core/serializers/serializeAmount', () => ({
  deserializeAmount: jest.fn((cents) => cents / 100),
}))

jest.mock('~/core/timezone/utils', () => ({
  intlFormatDateTime: jest.fn(() => ({ date: '2024-01-01' })),
}))

const createMockWallet = (overrides = {}) => ({
  id: 'wallet-1',
  name: 'Main Wallet',
  currency: 'USD',
  balanceCents: 10000,
  creditsBalance: 100.0,
  expirationAt: '2025-12-31T00:00:00Z',
  consumedCredits: 25,
  consumedAmountCents: 2500,
  status: 'active',
  creditsOngoingBalance: 75.0,
  ongoingBalanceCents: 7500,
  rateAmount: 1,
  lastBalanceSyncAt: null,
  paidTopUpMinAmountCents: null,
  paidTopUpMaxAmountCents: null,
  ...overrides,
})

const mockViewWallet = jest.fn()
const mockFetchMore = jest.fn()
const mockCustomerPortalUserRefetch = jest.fn()
const mockCustomerWalletRefetch = jest.fn()

const setupDefaultMocks = () => {
  mockUseCustomerPortalTranslate.mockReturnValue({
    translate: jest.fn((key: string) => key),
    documentLocale: 'en',
  })

  mockUseCustomerPortalData.mockReturnValue({
    data: {
      customerPortalUser: {
        applicableTimezone: 'UTC',
        premium: false,
      },
    },
    loading: false,
    error: undefined,
    refetch: mockCustomerPortalUserRefetch,
  })

  mockUseGetPortalWalletsQuery.mockReturnValue({
    data: {
      customerPortalWallets: {
        collection: [createMockWallet()],
        metadata: { currentPage: 1, totalPages: 1 },
      },
    },
    loading: false,
    error: undefined,
    refetch: mockCustomerWalletRefetch,
    fetchMore: mockFetchMore,
  })
}

describe('WalletSection', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    setupDefaultMocks()
  })

  // GIVEN data is loading
  // WHEN the component renders
  // THEN should render loading skeleton
  it('should render loading skeleton when data is loading', () => {
    mockUseGetPortalWalletsQuery.mockReturnValue({
      data: undefined,
      loading: true,
      error: undefined,
      refetch: mockCustomerWalletRefetch,
      fetchMore: mockFetchMore,
    })

    render(<WalletSection viewWallet={mockViewWallet} />)

    expect(screen.getByTestId('loading-skeleton')).toBeInTheDocument()
    expect(screen.queryByTestId(WALLET_SECTION_WALLET_ITEM_TEST_ID)).not.toBeInTheDocument()
  })

  // GIVEN there is a wallet query error
  // WHEN the component renders
  // THEN should render error state
  it('should render error state when wallet query fails', () => {
    mockUseGetPortalWalletsQuery.mockReturnValue({
      data: undefined,
      loading: false,
      error: new Error('Wallet error'),
      refetch: mockCustomerWalletRefetch,
      fetchMore: mockFetchMore,
    })

    render(<WalletSection viewWallet={mockViewWallet} />)

    expect(screen.getByTestId(WALLET_SECTION_ERROR_TEST_ID)).toBeInTheDocument()
    expect(screen.getByTestId('section-error')).toBeInTheDocument()
  })

  // GIVEN there is a customer portal data error
  // WHEN the component renders
  // THEN should render error state
  it('should render error state when customer portal data fails', () => {
    mockUseCustomerPortalData.mockReturnValue({
      data: undefined,
      loading: false,
      error: new Error('Customer portal error'),
      refetch: mockCustomerPortalUserRefetch,
    })

    render(<WalletSection viewWallet={mockViewWallet} />)

    expect(screen.getByTestId(WALLET_SECTION_ERROR_TEST_ID)).toBeInTheDocument()
    expect(screen.getByTestId('section-error')).toBeInTheDocument()
  })

  // GIVEN no wallets exist (empty collection, not loading)
  // WHEN the component renders
  // THEN should render nothing (null)
  it('should render nothing when no wallets exist and not loading', () => {
    mockUseGetPortalWalletsQuery.mockReturnValue({
      data: {
        customerPortalWallets: {
          collection: [],
          metadata: { currentPage: 0, totalPages: 0 },
        },
      },
      loading: false,
      error: undefined,
      refetch: mockCustomerWalletRefetch,
      fetchMore: mockFetchMore,
    })

    const { container } = render(<WalletSection viewWallet={mockViewWallet} />)

    expect(container.innerHTML).toBe('')
  })

  // GIVEN wallets are loaded
  // WHEN the component renders
  // THEN should render wallet items
  it('should render wallet items when wallets are loaded', () => {
    render(<WalletSection viewWallet={mockViewWallet} />)

    expect(screen.getByTestId(WALLET_SECTION_CONTENT_TEST_ID)).toBeInTheDocument()
    expect(screen.getByTestId(WALLET_SECTION_WALLET_ITEM_TEST_ID)).toBeInTheDocument()
  })

  // GIVEN a wallet has a name
  // WHEN the component renders
  // THEN should render the wallet item with the name
  it('should render wallet item with name when wallet has a name', () => {
    mockUseGetPortalWalletsQuery.mockReturnValue({
      data: {
        customerPortalWallets: {
          collection: [createMockWallet({ name: 'Premium Wallet' })],
          metadata: { currentPage: 1, totalPages: 1 },
        },
      },
      loading: false,
      error: undefined,
      refetch: mockCustomerWalletRefetch,
      fetchMore: mockFetchMore,
    })

    render(<WalletSection viewWallet={mockViewWallet} />)

    expect(screen.getByTestId(WALLET_SECTION_WALLET_ITEM_TEST_ID)).toBeInTheDocument()
  })

  // GIVEN the view button is clicked
  // WHEN the user clicks the view button
  // THEN should call viewWallet with the wallet id
  it('should call viewWallet with the wallet id when view button is clicked', async () => {
    render(<WalletSection viewWallet={mockViewWallet} />)

    const viewButton = screen.getByTestId(WALLET_SECTION_VIEW_BUTTON_TEST_ID)

    await userEvent.click(viewButton)

    expect(mockViewWallet).toHaveBeenCalledWith('wallet-1')
  })

  // GIVEN there are more pages
  // WHEN the component renders
  // THEN should show load more button
  it('should show load more button when there are more pages', () => {
    mockUseGetPortalWalletsQuery.mockReturnValue({
      data: {
        customerPortalWallets: {
          collection: [createMockWallet()],
          metadata: { currentPage: 1, totalPages: 3 },
        },
      },
      loading: false,
      error: undefined,
      refetch: mockCustomerWalletRefetch,
      fetchMore: mockFetchMore,
    })

    render(<WalletSection viewWallet={mockViewWallet} />)

    expect(screen.getByTestId(WALLET_SECTION_LOAD_MORE_TEST_ID)).toBeInTheDocument()
  })

  // GIVEN there are no more pages
  // WHEN the component renders
  // THEN should not show load more button
  it('should not show load more button when there are no more pages', () => {
    mockUseGetPortalWalletsQuery.mockReturnValue({
      data: {
        customerPortalWallets: {
          collection: [createMockWallet()],
          metadata: { currentPage: 1, totalPages: 1 },
        },
      },
      loading: false,
      error: undefined,
      refetch: mockCustomerWalletRefetch,
      fetchMore: mockFetchMore,
    })

    render(<WalletSection viewWallet={mockViewWallet} />)

    expect(screen.queryByTestId(WALLET_SECTION_LOAD_MORE_TEST_ID)).not.toBeInTheDocument()
  })
})
