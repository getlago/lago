import { ApolloError } from '@apollo/client'
import { screen } from '@testing-library/react'

import { GENERIC_PLACEHOLDER_TEST_ID } from '~/components/designSystem/GenericPlaceholder'
import WalletAlerts, {
  WALLET_ALERTS_EMPTY_TEST_ID,
  WALLET_ALERTS_LIST_TEST_ID,
  WALLET_ALERTS_LOADING_TEST_ID,
} from '~/components/wallets/WalletAlerts'
import { AlertTypeEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

let mockIsPremium = true

const mockOpenDeleteDialog = jest.fn()

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))
jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: mockIsPremium }),
}))
jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({ hasPermissions: () => true }),
}))
jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: { defaultCurrency: 'USD' },
  }),
}))
jest.mock('~/components/wallets/DeleteWalletAlertDialog', () => ({
  useDeleteWalletAlertDialog: () => ({
    openDeleteWalletAlertDialog: mockOpenDeleteDialog,
  }),
}))

const mockUseGetWalletAlertsQuery = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetWalletAlertsQuery: (...args: unknown[]) => mockUseGetWalletAlertsQuery(...args),
}))

const mockWallet = {
  id: 'wallet-1',
  currency: 'USD',
} as any

describe('WalletAlerts', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockIsPremium = true
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the query is loading', () => {
    describe('WHEN isPremium is true', () => {
      it('THEN should display loading skeletons', () => {
        mockUseGetWalletAlertsQuery.mockReturnValue({
          data: undefined,
          error: undefined,
          loading: true,
        })

        render(<WalletAlerts wallet={mockWallet} />)

        expect(screen.getByTestId(WALLET_ALERTS_LOADING_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId(WALLET_ALERTS_LIST_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(WALLET_ALERTS_EMPTY_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN there are no alerts', () => {
    describe('WHEN isPremium is true and loading is finished', () => {
      it('THEN should display the empty message', () => {
        mockUseGetWalletAlertsQuery.mockReturnValue({
          data: { walletAlerts: { collection: [] } },
          error: undefined,
          loading: false,
        })

        render(<WalletAlerts wallet={mockWallet} />)

        expect(screen.getByTestId(WALLET_ALERTS_EMPTY_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId(WALLET_ALERTS_LIST_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(WALLET_ALERTS_LOADING_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN alerts exist', () => {
    describe('WHEN isPremium is true and loading is finished', () => {
      it('THEN should display the alerts list', () => {
        mockUseGetWalletAlertsQuery.mockReturnValue({
          data: {
            walletAlerts: {
              collection: [
                {
                  id: 'alert-1',
                  alertType: AlertTypeEnum.WalletBalanceAmount,
                  walletId: 'wallet-1',
                  code: 'low-balance',
                  name: 'Low Balance Alert',
                  thresholds: [{ code: 'threshold-1', recurring: false, value: '1000' }],
                },
              ],
            },
          },
          error: undefined,
          loading: false,
        })

        render(<WalletAlerts wallet={mockWallet} />)

        expect(screen.getByTestId(WALLET_ALERTS_LIST_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId(WALLET_ALERTS_EMPTY_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(WALLET_ALERTS_LOADING_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the query returns an error', () => {
    describe('WHEN there is an error and loading is false', () => {
      it('THEN should display the error placeholder', () => {
        mockUseGetWalletAlertsQuery.mockReturnValue({
          data: undefined,
          error: new ApolloError({}),
          loading: false,
        })

        render(<WalletAlerts wallet={mockWallet} />)

        expect(screen.getByTestId(GENERIC_PLACEHOLDER_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId(WALLET_ALERTS_LOADING_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(WALLET_ALERTS_LIST_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })
})
