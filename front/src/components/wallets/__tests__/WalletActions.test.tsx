import { screen } from '@testing-library/react'

import { WalletStatusEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { WALLET_ACTIONS_DATA_TEST } from '../utils/dataTestConstants'
import WalletActions from '../WalletActions'

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

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: true }),
}))

jest.mock('~/hooks/useDeveloperTool', () => ({
  useDeveloperTool: () => ({
    setUrl: jest.fn(),
    openPanel: jest.fn(),
  }),
}))

jest.mock('~/components/wallets/TerminateCustomerWalletDialog', () => ({
  useTerminateCustomerWalletDialog: () => ({ openTerminateCustomerWalletDialog: jest.fn() }),
}))

jest.mock('~/components/wallets/VoidWalletDialog', () => ({
  VoidWalletDialog: () => null,
}))

describe('WalletActions', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN no walletId', () => {
    describe('WHEN rendered', () => {
      it('THEN should render nothing', () => {
        const { container } = render(
          <WalletActions customerId="customer-1" status={WalletStatusEnum.Active} />,
        )

        expect(container.innerHTML).toBe('')
      })
    })
  })

  describe('GIVEN no customerId', () => {
    describe('WHEN rendered', () => {
      it('THEN should render nothing', () => {
        const { container } = render(
          <WalletActions walletId="wallet-1" status={WalletStatusEnum.Active} />,
        )

        expect(container.innerHTML).toBe('')
      })
    })
  })

  describe('GIVEN a terminated wallet', () => {
    describe('WHEN rendered', () => {
      it('THEN should not show the action menu button', () => {
        render(
          <WalletActions
            walletId="wallet-1"
            customerId="customer-1"
            status={WalletStatusEnum.Terminated}
          />,
        )

        expect(screen.queryByTestId(WALLET_ACTIONS_DATA_TEST)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN an active wallet', () => {
    describe('WHEN rendered', () => {
      it('THEN should show the action menu button', () => {
        render(
          <WalletActions
            walletId="wallet-1"
            customerId="customer-1"
            status={WalletStatusEnum.Active}
          />,
        )

        expect(screen.getByTestId(WALLET_ACTIONS_DATA_TEST)).toBeInTheDocument()
      })
    })
  })
})
