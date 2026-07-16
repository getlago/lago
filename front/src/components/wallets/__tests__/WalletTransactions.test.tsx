import { screen } from '@testing-library/react'
import { Settings } from 'luxon'

import { CurrencyEnum, WalletStatusEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { WALLET_TRANSACTIONS_CONTAINER_TEST_ID, WalletTransactions } from '../WalletTransactions'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))
jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: true }),
}))
jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    intlFormatDateTimeOrgaTZ: () => ({ date: '2024-01-01' }),
  }),
}))
jest.mock('~/components/TimezoneDate', () => ({
  TimezoneDate: () => <span data-test="mock-timezone-date">date</span>,
}))
// Mock child components that make their own queries
jest.mock('~/components/wallets/WalletTransactionList', () => ({
  WalletTransactionList: () => <div data-test="mock-wallet-transaction-list" />,
}))
jest.mock('~/components/wallets/WalletTransactionListItem', () => ({
  WalletTransactionListItem: () => <div data-test="mock-wallet-transaction-list-item" />,
}))

const originalDefaultZone = Settings.defaultZone

const createMockWallet = (overrides = {}) =>
  ({
    id: 'wallet-1',
    balanceCents: '10000',
    consumedAmountCents: '5000',
    consumedCredits: '50',
    creditsBalance: 100,
    currency: CurrencyEnum.Usd,
    expirationAt: null,
    lastBalanceSyncAt: '2024-01-01T00:00:00Z',
    lastConsumedCreditAt: '2024-01-01T00:00:00Z',
    lastOngoingBalanceSyncAt: '2024-01-01T00:00:00Z',
    status: WalletStatusEnum.Active,
    terminatedAt: null,
    ongoingBalanceCents: '8000',
    creditsOngoingBalance: '80',
    rateAmount: 1,
    ongoingUsageBalanceCents: '0',
    creditsOngoingUsageBalance: 0,
    traceable: true,
    ...overrides,
  }) as any

describe('WalletTransactions', () => {
  beforeAll(() => {
    Settings.defaultZone = 'UTC'
  })

  afterAll(() => {
    Settings.defaultZone = originalDefaultZone
  })

  it('GIVEN active wallet WHEN rendered THEN should show transactions container', () => {
    const wallet = createMockWallet({ status: WalletStatusEnum.Active })

    render(<WalletTransactions wallet={wallet} />)

    const container = screen.getByTestId(WALLET_TRANSACTIONS_CONTAINER_TEST_ID)

    expect(container).toBeInTheDocument()

    // Active wallet shows the real-time transaction list item
    expect(screen.getByTestId('mock-wallet-transaction-list-item')).toBeInTheDocument()

    // Active wallet shows the transaction list
    expect(screen.getByTestId('mock-wallet-transaction-list')).toBeInTheDocument()
  })

  it('GIVEN terminated wallet WHEN rendered THEN should show transactions container', () => {
    const wallet = createMockWallet({
      status: WalletStatusEnum.Terminated,
      terminatedAt: '2024-06-01T00:00:00Z',
    })

    render(<WalletTransactions wallet={wallet} />)

    const container = screen.getByTestId(WALLET_TRANSACTIONS_CONTAINER_TEST_ID)

    expect(container).toBeInTheDocument()

    // Terminated wallet does not show the real-time transaction list item
    expect(screen.queryByTestId('mock-wallet-transaction-list-item')).not.toBeInTheDocument()

    // Terminated wallet still shows the transaction list
    expect(screen.getByTestId('mock-wallet-transaction-list')).toBeInTheDocument()
  })
})
