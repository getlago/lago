import { renderHook } from '@testing-library/react'

import { CurrencyEnum, WalletStatusEnum } from '~/generated/graphql'

import { useWalletActions, WalletActionItem } from '../useWalletActions'

const mockNavigate = jest.fn()
const mockTranslate = jest.fn((key: string) => key)
const mockHasPermissions = jest.fn(() => true)
const mockCopyToClipboard = jest.fn()
const mockAddToast = jest.fn()
const mockSetUrl = jest.fn()
const mockOpenPanel = jest.fn()

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => mockNavigate,
  generatePath: (route: string, params: Record<string, string>) => {
    let result = route

    Object.entries(params).forEach(([key, value]) => {
      result = result.replace(`:${key}`, value)
    })

    return result
  },
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: mockTranslate,
  }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
  }),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: true }),
}))

jest.mock('~/hooks/useDeveloperTool', () => ({
  useDeveloperTool: () => ({
    setUrl: mockSetUrl,
    openPanel: mockOpenPanel,
  }),
}))

jest.mock('~/core/utils/copyToClipboard', () => ({
  copyToClipboard: (...args: unknown[]) => mockCopyToClipboard(...args),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: (...args: unknown[]) => mockAddToast(...args),
  envGlobalVar: () => ({ appEnv: 'test' }),
}))

jest.mock('~/components/activityLogs/utils', () => ({
  buildLinkToActivityLog: (id: string, filter: string) => `/activity-log?${filter}=${id}`,
}))

const mockOpenTerminateCustomerWalletDialog = jest.fn()

jest.mock('~/components/wallets/TerminateCustomerWalletDialog', () => ({
  useTerminateCustomerWalletDialog: () => ({
    openTerminateCustomerWalletDialog: mockOpenTerminateCustomerWalletDialog,
  }),
}))

const defaultParams = {
  walletId: 'wallet-1',
  customerId: 'customer-1',
  status: WalletStatusEnum.Active,
  creditsBalance: 100,
  rateAmount: 1,
  currency: CurrencyEnum.Usd,
}

const getVisibleActions = (actions: WalletActionItem[]) =>
  actions.filter((action) => !action.hidden)

describe('useWalletActions', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockHasPermissions.mockReturnValue(true)
  })

  describe('GIVEN the hook is called with an active wallet', () => {
    describe('WHEN user has all permissions', () => {
      it('THEN should return 7 actions in total', () => {
        const { result } = renderHook(() => useWalletActions(defaultParams))

        expect(result.current.actions).toHaveLength(7)
      })

      it('THEN should return voidDialogRef', () => {
        const { result } = renderHook(() => useWalletActions(defaultParams))

        expect(result.current.voidDialogRef).toBeDefined()
      })

      it('THEN should have all actions visible', () => {
        const { result } = renderHook(() => useWalletActions(defaultParams))

        const visible = getVisibleActions(result.current.actions)

        expect(visible).toHaveLength(7)
      })
    })
  })

  describe('GIVEN the wallet is terminated', () => {
    describe('WHEN the hook is called', () => {
      it('THEN should hide all actions', () => {
        const { result } = renderHook(() =>
          useWalletActions({ ...defaultParams, status: WalletStatusEnum.Terminated }),
        )

        const visible = getVisibleActions(result.current.actions)

        expect(visible).toHaveLength(0)
      })
    })
  })

  describe('GIVEN specific permissions are missing', () => {
    describe('WHEN user lacks walletsUpdate permission', () => {
      it('THEN should hide the edit action', () => {
        mockHasPermissions.mockImplementation(((perms: string[]) => {
          if (perms.includes('walletsUpdate')) return false

          return true
        }) as unknown as () => boolean)

        const { result } = renderHook(() => useWalletActions(defaultParams))

        // Edit action is at index 2
        expect(result.current.actions[2].hidden).toBe(true)
      })
    })

    describe('WHEN user lacks walletsTerminate permission', () => {
      it('THEN should hide the void credits and terminate actions', () => {
        mockHasPermissions.mockImplementation(((perms: string[]) => {
          if (perms.includes('walletsTerminate')) return false

          return true
        }) as unknown as () => boolean)

        const { result } = renderHook(() => useWalletActions(defaultParams))

        // Void credits action is at index 3
        expect(result.current.actions[3].hidden).toBe(true)
        // Terminate action is at index 6
        expect(result.current.actions[6].hidden).toBe(true)
      })
    })

    describe('WHEN user lacks auditLogsView permission', () => {
      it('THEN should hide the activity logs action', () => {
        mockHasPermissions.mockImplementation(((perms: string[]) => {
          if (perms.includes('auditLogsView')) return false

          return true
        }) as unknown as () => boolean)

        const { result } = renderHook(() => useWalletActions(defaultParams))

        // Activity logs action is at index 5
        expect(result.current.actions[5].hidden).toBe(true)
      })
    })
  })

  describe('GIVEN the wallet has zero or negative credits balance', () => {
    describe('WHEN creditsBalance is 0', () => {
      it('THEN should not disable the void credits action (0 is falsy in the guard)', () => {
        const { result } = renderHook(() =>
          useWalletActions({ ...defaultParams, creditsBalance: 0 }),
        )

        // creditsBalance of 0 is falsy, so the guard `!!(creditsBalance && ...)` is false
        expect(result.current.actions[3].disabled).toBe(false)
      })
    })

    describe('WHEN creditsBalance is negative', () => {
      it('THEN should disable the void credits action', () => {
        const { result } = renderHook(() =>
          useWalletActions({ ...defaultParams, creditsBalance: -10 }),
        )

        expect(result.current.actions[3].disabled).toBe(true)
      })
    })
  })

  describe('GIVEN the terminate action has danger flag', () => {
    describe('WHEN the hook is called', () => {
      it('THEN should mark the terminate action as danger', () => {
        const { result } = renderHook(() => useWalletActions(defaultParams))

        // Terminate action is at index 6
        expect(result.current.actions[6].danger).toBe(true)
      })
    })
  })

  describe('GIVEN action callbacks are invoked', () => {
    const closePopper = jest.fn()

    beforeEach(() => {
      closePopper.mockClear()
    })

    describe('WHEN the top up action is clicked', () => {
      it('THEN should navigate to the top up route and close popper', () => {
        const { result } = renderHook(() => useWalletActions(defaultParams))

        result.current.actions[0].onAction(closePopper)

        expect(mockNavigate).toHaveBeenCalledWith('/customer/customer-1/wallet/wallet-1/top-up')
        expect(closePopper).toHaveBeenCalled()
      })
    })

    describe('WHEN the copy ID action is clicked', () => {
      it('THEN should copy wallet ID to clipboard and show toast', () => {
        const { result } = renderHook(() => useWalletActions(defaultParams))

        result.current.actions[1].onAction(closePopper)

        expect(mockCopyToClipboard).toHaveBeenCalledWith('wallet-1')
        expect(mockAddToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'info' }))
        expect(closePopper).toHaveBeenCalled()
      })
    })

    describe('WHEN the edit action is clicked', () => {
      it('THEN should navigate to the edit wallet route and close popper', () => {
        const { result } = renderHook(() => useWalletActions(defaultParams))

        result.current.actions[2].onAction(closePopper)

        expect(mockNavigate).toHaveBeenCalledWith('/customer/customer-1/wallet/wallet-1')
        expect(closePopper).toHaveBeenCalled()
      })
    })

    describe('WHEN the void credits action is clicked', () => {
      it('THEN should open the void dialog and close popper', () => {
        const { result } = renderHook(() => useWalletActions(defaultParams))

        const mockOpenDialog = jest.fn()

        ;(
          result.current.voidDialogRef as unknown as { current: { openDialog: jest.Mock } }
        ).current = { openDialog: mockOpenDialog }

        result.current.actions[3].onAction(closePopper)

        expect(mockOpenDialog).toHaveBeenCalledWith({
          walletId: 'wallet-1',
          rateAmount: 1,
          creditsBalance: 100,
          currency: CurrencyEnum.Usd,
        })
        expect(closePopper).toHaveBeenCalled()
      })
    })

    describe('WHEN the alerts action is clicked', () => {
      it('THEN should navigate to the wallet details alerts tab and close popper', () => {
        const { result } = renderHook(() => useWalletActions(defaultParams))

        result.current.actions[4].onAction(closePopper)

        expect(mockNavigate).toHaveBeenCalledWith(
          '/customer/customer-1/wallet-details/wallet-1/alerts',
        )
        expect(closePopper).toHaveBeenCalled()
      })
    })

    describe('WHEN the activity logs action is clicked', () => {
      it('THEN should set URL and open the developer tool panel', () => {
        const { result } = renderHook(() => useWalletActions(defaultParams))

        result.current.actions[5].onAction(closePopper)

        expect(mockSetUrl).toHaveBeenCalledWith('/activity-log?resourceIds=wallet-1')
        expect(mockOpenPanel).toHaveBeenCalled()
        expect(closePopper).toHaveBeenCalled()
      })
    })

    describe('WHEN the terminate action is clicked', () => {
      it('THEN should open the terminate dialog and close popper', () => {
        const { result } = renderHook(() => useWalletActions(defaultParams))

        result.current.actions[6].onAction(closePopper)

        expect(mockOpenTerminateCustomerWalletDialog).toHaveBeenCalledWith({
          walletId: 'wallet-1',
        })
        expect(closePopper).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN action icons are configured correctly', () => {
    describe('WHEN the hook returns actions', () => {
      it.each([
        ['top up', 0, 'plus'],
        ['copy ID', 1, 'duplicate'],
        ['edit', 2, 'pen'],
        ['void credits', 3, 'minus'],
        ['alerts', 4, 'bell'],
        ['activity logs', 5, 'pulse'],
        ['terminate', 6, 'trash'],
      ])('THEN should set correct startIcon for %s action', (_, index, expectedIcon) => {
        const { result } = renderHook(() => useWalletActions(defaultParams))

        expect(result.current.actions[index].startIcon).toBe(expectedIcon)
      })
    })
  })

  describe('GIVEN no walletId is provided', () => {
    describe('WHEN copy ID action is clicked', () => {
      it('THEN should copy an empty string', () => {
        const closePopper = jest.fn()
        const { result } = renderHook(() =>
          useWalletActions({ ...defaultParams, walletId: undefined }),
        )

        result.current.actions[1].onAction(closePopper)

        expect(mockCopyToClipboard).toHaveBeenCalledWith('')
      })
    })
  })
})
