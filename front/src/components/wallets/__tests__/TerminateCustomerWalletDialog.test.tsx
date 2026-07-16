import { act, renderHook } from '@testing-library/react'

import { useTerminateCustomerWalletDialog } from '../TerminateCustomerWalletDialog'

const mockTerminateWallet = jest.fn()
const mockOpen = jest.fn()

jest.mock('~/components/dialogs/CentralizedDialog', () => ({
  useCentralizedDialog: () => ({ open: mockOpen, close: jest.fn() }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useTerminateCustomerWalletMutation: () => [mockTerminateWallet],
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

jest.mock('~/core/router', () => ({
  ...jest.requireActual('~/core/router'),
  useNavigate: () => jest.fn(),
}))

describe('useTerminateCustomerWalletDialog', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({ customerId: 'customer-1' })
  })

  describe('WHEN openTerminateCustomerWalletDialog is called without props', () => {
    it('THEN should not open the dialog', () => {
      const { result } = renderHook(() => useTerminateCustomerWalletDialog())

      act(() => {
        result.current.openTerminateCustomerWalletDialog(undefined)
      })

      expect(mockOpen).not.toHaveBeenCalled()
    })
  })

  describe('WHEN openTerminateCustomerWalletDialog is called with walletId', () => {
    it('THEN should open the centralized dialog', () => {
      const { result } = renderHook(() => useTerminateCustomerWalletDialog())

      act(() => {
        result.current.openTerminateCustomerWalletDialog({ walletId: 'wallet-1' })
      })

      expect(mockOpen).toHaveBeenCalledTimes(1)
      expect(mockOpen).toHaveBeenCalledWith(
        expect.objectContaining({
          colorVariant: 'danger',
        }),
      )
    })
  })
})
