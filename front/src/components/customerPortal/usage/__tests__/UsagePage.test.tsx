import { ApolloError } from '@apollo/client'
import { act, waitFor } from '@testing-library/react'

import { addToast } from '~/core/apolloClient'
import { CUSTOMER_PORTAL_ROUTE } from '~/core/router/paths/customerPortal'
import { LagoApiError } from '~/generated/graphql'
import { render } from '~/test-utils'

import UsagePage from '../UsagePage'

const mockNavigate = jest.fn()
const mockUseCustomerPortalData = jest.fn()
const mockUseGetSubscriptionForPortalQuery = jest.fn()
const mockUseGetCustomerUsageForPortalQuery = jest.fn()
const mockUseGetCustomerProjectedUsageForPortalQuery = jest.fn()

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useParams: () => ({ itemId: 'test-subscription-id', token: 'test-token' }),
  useNavigate: () => mockNavigate,
  generatePath: jest.fn((route: string, params: { token: string }) => {
    return route.replace(':token', params.token)
  }),
}))

jest.mock('~/components/customerPortal/common/hooks/useCustomerPortalNavigation', () => ({
  __esModule: true,
  default: jest.fn(() => ({
    goHome: jest.fn(),
  })),
}))

jest.mock('~/components/customerPortal/common/useCustomerPortalTranslate', () => ({
  __esModule: true,
  default: jest.fn(() => ({
    translate: jest.fn((key: string) => key),
    documentLocale: 'en',
  })),
}))

jest.mock('~/components/customerPortal/usage/UsageSubscriptionItem', () => ({
  __esModule: true,
  default: () => <div data-test="mock-usage-subscription-item" />,
}))

jest.mock('~/components/subscriptions/SubscriptionUsageLifetimeGraph', () => ({
  __esModule: true,
  SubscriptionUsageLifetimeGraphComponent: () => (
    <div data-test="mock-subscription-usage-lifetime-graph" />
  ),
}))

jest.mock('~/components/subscriptions/SubscriptionCurrentUsageTable', () => ({
  __esModule: true,
  SubscriptionCurrentUsageTableComponent: () => (
    <div data-test="mock-subscription-current-usage-table" />
  ),
}))

jest.mock('~/components/customerPortal/common/hooks/useCustomerPortalData', () => ({
  useCustomerPortalData: () => mockUseCustomerPortalData(),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetSubscriptionForPortalQuery: jest.fn(() => mockUseGetSubscriptionForPortalQuery()),
  useGetCustomerUsageForPortalQuery: jest.fn(() => mockUseGetCustomerUsageForPortalQuery()),
  useGetCustomerProjectedUsageForPortalQuery: jest.fn(() =>
    mockUseGetCustomerProjectedUsageForPortalQuery(),
  ),
}))

const createNoActiveSubscriptionError = (): ApolloError =>
  ({
    graphQLErrors: [
      {
        message: 'No active subscription',
        extensions: {
          code: LagoApiError.NoActiveSubscription,
        },
      },
    ],
  }) as unknown as ApolloError

const setupDefaultMocks = () => {
  mockUseCustomerPortalData.mockReturnValue({
    data: {
      customerPortalOrganization: {
        premiumIntegrations: [],
      },
    },
    loading: false,
  })

  mockUseGetSubscriptionForPortalQuery.mockReturnValue({
    data: {
      customerPortalSubscription: {
        id: 'test-subscription-id',
        name: 'Test Subscription',
        customer: {
          id: 'test-customer-id',
          currency: 'USD',
          applicableTimezone: 'UTC',
        },
        lifetimeUsage: null,
        plan: {
          id: 'test-plan-id',
          name: 'Test Plan',
          code: 'test-plan',
          amountCents: 1000,
          amountCurrency: 'USD',
          interval: 'monthly',
        },
      },
    },
    loading: false,
    error: undefined,
    refetch: jest.fn(),
  })

  mockUseGetCustomerUsageForPortalQuery.mockReturnValue({
    data: {
      customerPortalCustomerUsage: {
        amountCents: 500,
      },
    },
    loading: false,
    error: undefined,
    refetch: jest.fn(),
  })

  mockUseGetCustomerProjectedUsageForPortalQuery.mockReturnValue({
    data: null,
    loading: false,
    error: undefined,
    refetch: jest.fn(),
  })
}

describe('UsagePage', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    setupDefaultMocks()
  })

  describe('NoActiveSubscription error handling', () => {
    it('should show toast and redirect when usageError has NoActiveSubscription error', async () => {
      const noActiveSubscriptionError = createNoActiveSubscriptionError()

      mockUseGetCustomerUsageForPortalQuery.mockReturnValue({
        data: null,
        loading: false,
        error: noActiveSubscriptionError,
        refetch: jest.fn(),
      })

      await act(async () => {
        render(<UsagePage />)
      })

      await waitFor(() => {
        expect(addToast).toHaveBeenCalledWith({
          severity: 'info',
          translateKey: 'text_173142196943714qsq737sre',
        })
      })

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith(
          CUSTOMER_PORTAL_ROUTE.replace(':token', 'test-token'),
          { replace: true },
        )
      })
    })

    it('should show toast and redirect when usageErrorProjected has NoActiveSubscription error', async () => {
      const noActiveSubscriptionError = createNoActiveSubscriptionError()

      mockUseCustomerPortalData.mockReturnValue({
        data: {
          customerPortalOrganization: {
            premiumIntegrations: ['projected_usage'],
          },
        },
        loading: false,
      })

      mockUseGetCustomerProjectedUsageForPortalQuery.mockReturnValue({
        data: null,
        loading: false,
        error: noActiveSubscriptionError,
        refetch: jest.fn(),
      })

      await act(async () => {
        render(<UsagePage />)
      })

      await waitFor(() => {
        expect(addToast).toHaveBeenCalledWith({
          severity: 'info',
          translateKey: 'text_173142196943714qsq737sre',
        })
      })

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith(
          CUSTOMER_PORTAL_ROUTE.replace(':token', 'test-token'),
          { replace: true },
        )
      })
    })

    it('should not redirect when there is no NoActiveSubscription error', async () => {
      await act(async () => {
        render(<UsagePage />)
      })

      await waitFor(() => {
        expect(addToast).not.toHaveBeenCalled()
        expect(mockNavigate).not.toHaveBeenCalled()
      })
    })

    it('should not redirect when there is a different error type', async () => {
      const differentError: ApolloError = {
        graphQLErrors: [
          {
            message: 'Some other error',
            extensions: {
              code: LagoApiError.Forbidden,
            },
          },
        ],
      } as unknown as ApolloError

      mockUseGetCustomerUsageForPortalQuery.mockReturnValue({
        data: null,
        loading: false,
        error: differentError,
        refetch: jest.fn(),
      })

      await act(async () => {
        render(<UsagePage />)
      })

      await waitFor(() => {
        expect(addToast).not.toHaveBeenCalled()
        expect(mockNavigate).not.toHaveBeenCalled()
      })
    })
  })
})
