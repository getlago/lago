import { screen } from '@testing-library/react'

import { render } from '~/test-utils'

import {
  CUSTOMER_WALLET_LIST_EMPTY_TEST_ID,
  CUSTOMER_WALLET_LIST_LOADING_TEST_ID,
  CustomerWalletsList,
} from '../CustomerWalletList'
import { CREATE_WALLET_DATA_TEST } from '../utils/dataTestConstants'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: () => true,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: { defaultCurrency: 'USD' },
    intlFormatDateTimeOrgaTZ: () => ({ date: '2024-01-01' }),
  }),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: true }),
}))

jest.mock('~/hooks/useDeveloperTool', () => ({
  useDeveloperTool: () => ({
    setUrl: jest.fn(),
    openPanel: jest.fn(),
  }),
}))

jest.mock('~/components/wallets/WalletActions', () => ({
  __esModule: true,
  default: () => <div data-test="mock-wallet-actions" />,
}))

const mockUseGetCustomerWalletListQuery = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetCustomerWalletListQuery: (...args: unknown[]) => mockUseGetCustomerWalletListQuery(...args),
}))

const mockIntersectionObserver = jest.fn()

mockIntersectionObserver.mockReturnValue({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
})
window.IntersectionObserver = mockIntersectionObserver

describe('CustomerWalletsList', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN loading state', () => {
    describe('WHEN rendered', () => {
      it('THEN should show loading skeleton', () => {
        mockUseGetCustomerWalletListQuery.mockReturnValue({
          data: undefined,
          error: undefined,
          loading: true,
          fetchMore: jest.fn(),
        })

        render(<CustomerWalletsList customerId="customer-1" />)

        expect(screen.getByTestId(CUSTOMER_WALLET_LIST_LOADING_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN no wallets', () => {
    describe('WHEN loaded', () => {
      it('THEN should show empty message', () => {
        mockUseGetCustomerWalletListQuery.mockReturnValue({
          data: {
            wallets: {
              collection: [],
              metadata: { currentPage: 1, totalPages: 1, customerActiveWalletsCount: 0 },
            },
          },
          error: undefined,
          loading: false,
          fetchMore: jest.fn(),
        })

        render(<CustomerWalletsList customerId="customer-1" />)

        expect(screen.getByTestId(CUSTOMER_WALLET_LIST_EMPTY_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN wallets exist', () => {
    describe('WHEN loaded', () => {
      it('THEN should show create wallet button', () => {
        mockUseGetCustomerWalletListQuery.mockReturnValue({
          data: {
            wallets: {
              collection: [
                {
                  id: 'wallet-1',
                  name: 'Test Wallet',
                  status: 'active',
                  currency: 'USD',
                  balanceCents: '10000',
                  creditsBalance: 100,
                  ongoingBalanceCents: '8000',
                  creditsOngoingBalance: 80,
                  rateAmount: 1,
                  priority: 1,
                  createdAt: '2024-01-01T00:00:00Z',
                  expirationAt: null,
                  consumedAmountCents: '0',
                  consumedCredits: '0',
                  lastBalanceSyncAt: '2024-01-01T00:00:00Z',
                  lastConsumedCreditAt: null,
                  lastOngoingBalanceSyncAt: '2024-01-01T00:00:00Z',
                  terminatedAt: null,
                  ongoingUsageBalanceCents: '0',
                  creditsOngoingUsageBalance: 0,
                  traceable: true,
                },
              ],
              metadata: { currentPage: 1, totalPages: 1, customerActiveWalletsCount: 1 },
            },
          },
          error: undefined,
          loading: false,
          fetchMore: jest.fn(),
        })

        render(<CustomerWalletsList customerId="customer-1" />)

        expect(screen.getByTestId(CREATE_WALLET_DATA_TEST)).toBeInTheDocument()
        expect(screen.queryByTestId(CUSTOMER_WALLET_LIST_LOADING_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(CUSTOMER_WALLET_LIST_EMPTY_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN error state', () => {
    describe('WHEN not loading', () => {
      it('THEN should show error placeholder', () => {
        mockUseGetCustomerWalletListQuery.mockReturnValue({
          data: undefined,
          error: new Error('test error'),
          loading: false,
          fetchMore: jest.fn(),
        })

        render(<CustomerWalletsList customerId="customer-1" />)

        expect(screen.queryByTestId(CUSTOMER_WALLET_LIST_LOADING_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(CUSTOMER_WALLET_LIST_EMPTY_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })
})
