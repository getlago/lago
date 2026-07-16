import { renderHook } from '@testing-library/react'

import { CustomerAccountTypeEnum, CustomerDetailsFragment } from '~/generated/graphql'

import { useCustomerDetailsHeaderTabs } from '../useCustomerDetailsHeaderTabs'

const mockNavigate = jest.fn()
const mockHasPermissions = jest.fn(() => true)

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
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
  }),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({
    isPremium: true,
  }),
}))

// Mock child components to avoid rendering them
jest.mock('~/components/customers/CustomerActivityLogs', () => ({
  CustomerActivityLogs: () => null,
}))

jest.mock('~/components/customers/CustomerCreditNotesList', () => ({
  CustomerCreditNotesList: () => null,
}))

jest.mock('~/components/customers/CustomerInvoicesTab', () => ({
  CustomerInvoicesTab: () => null,
}))

jest.mock('~/components/customers/CustomerMainInfos', () => ({
  CustomerMainInfos: () => null,
}))

jest.mock('~/components/customers/CustomerPaymentsTab', () => ({
  CustomerPaymentsTab: () => null,
}))

jest.mock('~/components/customers/CustomerSettings', () => ({
  CustomerSettings: () => null,
}))

jest.mock('~/components/customers/CustomerAppliedCouponsList', () => ({
  CustomerAppliedCouponsList: () => null,
}))

jest.mock('~/components/customers/overview/CustomerSubscriptionsList', () => ({
  CustomerSubscriptionsList: () => null,
}))

jest.mock('~/components/customers/usage/CustomerUsage', () => ({
  CustomerUsage: () => null,
}))

jest.mock('~/components/wallets/CustomerWalletList', () => ({
  CustomerWalletsList: () => null,
}))

const createMockCustomer = (
  overrides: Partial<CustomerDetailsFragment> = {},
): CustomerDetailsFragment =>
  ({
    id: 'cust-1',
    displayName: 'Test Customer',
    externalId: 'ext-1',
    hasActiveWallet: false,
    hasCreditNotes: true,
    currency: 'USD',
    applicableTimezone: 'UTC',
    creditNotesCreditsAvailableCount: 2,
    creditNotesBalanceAmountCents: 5000,
    accountType: CustomerAccountTypeEnum.Customer,
    ...overrides,
  }) as unknown as CustomerDetailsFragment

const defaultParams = {
  customerId: 'cust-1',
  customer: createMockCustomer(),
  loading: false,
}

describe('useCustomerDetailsHeaderTabs', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockHasPermissions.mockReturnValue(true)
  })

  describe('GIVEN a customer is provided', () => {
    describe('WHEN user has all permissions', () => {
      it('THEN should return the full set of tabs', () => {
        const { result } = renderHook(() => useCustomerDetailsHeaderTabs(defaultParams))

        expect(result.current).toBeDefined()
        // overview, coupons, wallet, usage, invoices, payments, credit notes, information, settings, activity logs
        expect(result.current).toHaveLength(10)
      })

      it.each([
        ['overview', 0],
        ['coupons', 1],
        ['wallet', 2],
        ['usage', 3],
        ['invoices', 4],
        ['payments', 5],
        ['credit notes', 6],
        ['information', 7],
        ['settings', 8],
        ['activity logs', 9],
      ])('THEN should include the %s tab at index %i', (_, index) => {
        const { result } = renderHook(() => useCustomerDetailsHeaderTabs(defaultParams))

        expect(result.current?.[index]).toBeDefined()
        expect(result.current?.[index].title).toEqual(expect.any(String))
        expect(result.current?.[index].content).toBeDefined()
      })
    })

    describe('WHEN user does not have analyticsView permission', () => {
      it('THEN should hide the usage tab', () => {
        mockHasPermissions.mockImplementation(((perms: string[]) => {
          if (perms.includes('analyticsView')) return false

          return true
        }) as unknown as () => boolean)

        const { result } = renderHook(() => useCustomerDetailsHeaderTabs(defaultParams))

        // Usage tab is index 3
        expect(result.current?.[3].hidden).toBe(true)
      })
    })

    describe('WHEN user does not have customersView permission', () => {
      it('THEN should hide the settings tab', () => {
        mockHasPermissions.mockImplementation(((perms: string[]) => {
          if (perms.includes('customersView')) return false

          return true
        }) as unknown as () => boolean)

        const { result } = renderHook(() => useCustomerDetailsHeaderTabs(defaultParams))

        // Settings tab is index 8
        expect(result.current?.[8].hidden).toBe(true)
      })
    })

    describe('WHEN customer has no credit notes', () => {
      it('THEN should hide the credit notes tab', () => {
        const params = {
          ...defaultParams,
          customer: createMockCustomer({ hasCreditNotes: false }),
        }

        const { result } = renderHook(() => useCustomerDetailsHeaderTabs(params))

        // Credit notes tab is index 6
        expect(result.current?.[6].hidden).toBe(true)
      })
    })

    describe('WHEN customer has no externalId', () => {
      it('THEN should hide the activity logs tab', () => {
        const params = {
          ...defaultParams,
          customer: createMockCustomer({ externalId: '' }),
        }

        const { result } = renderHook(() => useCustomerDetailsHeaderTabs(params))

        // Activity logs tab is index 9
        expect(result.current?.[9].hidden).toBe(true)
      })
    })

    describe('WHEN the wallet tab has a data-test attribute', () => {
      it('THEN should set the correct dataTest value', () => {
        const { result } = renderHook(() => useCustomerDetailsHeaderTabs(defaultParams))

        expect(result.current?.[2].dataTest).toBe('wallet-tab')
      })
    })
  })

  describe('GIVEN no customer is provided', () => {
    describe('WHEN customer is undefined', () => {
      it('THEN should return undefined', () => {
        const params = { ...defaultParams, customer: undefined }

        const { result } = renderHook(() => useCustomerDetailsHeaderTabs(params))

        expect(result.current).toBeUndefined()
      })
    })

    describe('WHEN customer is null', () => {
      it('THEN should return undefined', () => {
        const params = { ...defaultParams, customer: null }

        const { result } = renderHook(() => useCustomerDetailsHeaderTabs(params))

        expect(result.current).toBeUndefined()
      })
    })
  })
})
