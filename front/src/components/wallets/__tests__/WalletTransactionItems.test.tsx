import { ApolloError } from '@apollo/client'
import { act, screen } from '@testing-library/react'

import { GENERIC_PLACEHOLDER_TEST_ID } from '~/components/designSystem/GenericPlaceholder'
import {
  WALLET_TRANSACTION_ITEM_ROW_TEST_ID,
  WALLET_TRANSACTION_ITEMS_LIST_TEST_ID,
  WALLET_TRANSACTION_ITEMS_LOADING_TEST_ID,
} from '~/components/wallets/utils/dataTestConstants'
import WalletTransactionItems from '~/components/wallets/WalletTransactionItems'
import {
  CurrencyEnum,
  TimezoneEnum,
  WalletStatusEnum,
  WalletTransactionConsumptionItemFragment,
  WalletTransactionTransactionStatusEnum,
} from '~/generated/graphql'
import { render } from '~/test-utils'

// Mock IntersectionObserver for InfiniteScroll
const mockIntersectionObserver = jest.fn()

mockIntersectionObserver.mockReturnValue({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
})
window.IntersectionObserver = mockIntersectionObserver

const mockFetchMore = jest.fn()

const mockWallet = {
  id: 'wallet-1',
  currency: CurrencyEnum.Usd,
  status: WalletStatusEnum.Active,
  ongoingUsageBalanceCents: '0',
  creditsOngoingUsageBalance: 0,
  rateAmount: 1,
  traceable: true,
}

const createMockTransaction = (
  overrides: Partial<WalletTransactionConsumptionItemFragment> = {},
): WalletTransactionConsumptionItemFragment => ({
  id: 'consumption-1',
  amountCents: '10000',
  createdAt: '2024-01-15T10:30:00Z',
  creditAmount: '100',
  walletTransaction: {
    id: 'wt-1',
    transactionStatus: WalletTransactionTransactionStatusEnum.Purchased,
  },
  ...overrides,
})

describe('WalletTransactionItems', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the component is loading', () => {
    describe('WHEN isLoading is true', () => {
      it('THEN should display loading skeletons', () => {
        render(
          <WalletTransactionItems
            isLoading={true}
            error={undefined}
            transactions={undefined}
            isConsumption={true}
            pagination={{ fetchMore: mockFetchMore }}
            wallet={mockWallet}
            customerId="customer-1"
            timezone={TimezoneEnum.TzUtc}
          />,
        )

        expect(screen.getByTestId(WALLET_TRANSACTION_ITEMS_LOADING_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId(WALLET_TRANSACTION_ITEMS_LIST_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN there is an error', () => {
    describe('WHEN error is present and not loading', () => {
      it('THEN should display the error placeholder', () => {
        render(
          <WalletTransactionItems
            isLoading={false}
            error={new ApolloError({})}
            transactions={undefined}
            isConsumption={true}
            pagination={{ fetchMore: mockFetchMore }}
            wallet={mockWallet}
            customerId="customer-1"
            timezone={TimezoneEnum.TzUtc}
          />,
        )

        expect(screen.getByTestId(GENERIC_PLACEHOLDER_TEST_ID)).toBeInTheDocument()
        expect(
          screen.queryByTestId(WALLET_TRANSACTION_ITEMS_LOADING_TEST_ID),
        ).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN there are no transactions', () => {
    describe('WHEN transactions array is empty', () => {
      it('THEN should render nothing', () => {
        const { container } = render(
          <WalletTransactionItems
            isLoading={false}
            error={undefined}
            transactions={[]}
            isConsumption={true}
            pagination={{ fetchMore: mockFetchMore }}
            wallet={mockWallet}
            customerId="customer-1"
            timezone={TimezoneEnum.TzUtc}
          />,
        )

        expect(screen.queryByTestId(WALLET_TRANSACTION_ITEMS_LIST_TEST_ID)).not.toBeInTheDocument()
        expect(
          screen.queryByTestId(WALLET_TRANSACTION_ITEMS_LOADING_TEST_ID),
        ).not.toBeInTheDocument()
        expect(container.children.length).toBe(0)
      })
    })
  })

  describe('GIVEN transactions data is available', () => {
    describe('WHEN rendering transaction items', () => {
      it('THEN should display the transaction list', () => {
        const transactions = [
          createMockTransaction({ id: 'consumption-1' }),
          createMockTransaction({ id: 'consumption-2' }),
        ]

        render(
          <WalletTransactionItems
            isLoading={false}
            error={undefined}
            transactions={transactions}
            isConsumption={true}
            pagination={{ currentPage: 1, totalPages: 1, fetchMore: mockFetchMore }}
            wallet={mockWallet}
            customerId="customer-1"
            timezone={TimezoneEnum.TzUtc}
          />,
        )

        expect(screen.getByTestId(WALLET_TRANSACTION_ITEMS_LIST_TEST_ID)).toBeInTheDocument()
        expect(screen.getAllByTestId(WALLET_TRANSACTION_ITEM_ROW_TEST_ID)).toHaveLength(2)
      })
    })
  })

  describe('GIVEN there are multiple pages of transactions', () => {
    describe('WHEN the user scrolls to the bottom', () => {
      it('THEN should call fetchMore with the next page', () => {
        const transactions = [createMockTransaction({ id: 'consumption-1' })]

        // Capture the IntersectionObserver callback
        let intersectionCallback: (entries: Array<{ isIntersecting: boolean }>) => void = () =>
          undefined

        mockIntersectionObserver.mockImplementation(
          (callback: (entries: Array<{ isIntersecting: boolean }>) => void) => {
            intersectionCallback = callback

            return { observe: jest.fn(), unobserve: jest.fn(), disconnect: jest.fn() }
          },
        )

        render(
          <WalletTransactionItems
            isLoading={false}
            error={undefined}
            transactions={transactions}
            isConsumption={true}
            pagination={{ currentPage: 1, totalPages: 3, fetchMore: mockFetchMore }}
            wallet={mockWallet}
            customerId="customer-1"
            timezone={TimezoneEnum.TzUtc}
          />,
        )

        // Simulate scroll to bottom
        act(() => {
          intersectionCallback([{ isIntersecting: true }])
        })

        expect(mockFetchMore).toHaveBeenCalledWith({ variables: { page: 2 } })
      })

      it('THEN should not call fetchMore when already on the last page', () => {
        const transactions = [createMockTransaction({ id: 'consumption-1' })]

        let intersectionCallback: (entries: Array<{ isIntersecting: boolean }>) => void = () =>
          undefined

        mockIntersectionObserver.mockImplementation(
          (callback: (entries: Array<{ isIntersecting: boolean }>) => void) => {
            intersectionCallback = callback

            return { observe: jest.fn(), unobserve: jest.fn(), disconnect: jest.fn() }
          },
        )

        render(
          <WalletTransactionItems
            isLoading={false}
            error={undefined}
            transactions={transactions}
            isConsumption={true}
            pagination={{ currentPage: 3, totalPages: 3, fetchMore: mockFetchMore }}
            wallet={mockWallet}
            customerId="customer-1"
            timezone={TimezoneEnum.TzUtc}
          />,
        )

        act(() => {
          intersectionCallback([{ isIntersecting: true }])
        })

        expect(mockFetchMore).not.toHaveBeenCalled()
      })
    })
  })
})
