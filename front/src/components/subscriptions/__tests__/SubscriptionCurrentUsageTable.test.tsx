import { ApolloError } from '@apollo/client'
import { render, waitFor } from '@testing-library/react'

import { addToast } from '~/core/apolloClient'
import { CustomerSubscriptionDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { LagoApiError, StatusTypeEnum } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { SubscriptionCurrentUsageTable } from '../SubscriptionCurrentUsageTable'

const mockNavigate = jest.fn()
const mockUseParams = jest.fn()

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => mockNavigate,
  useParams: (...args: unknown[]) => mockUseParams(...args),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: { premiumIntegrations: [] },
  }),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

jest.mock('~/components/dialogs/PremiumWarningDialog', () => ({
  usePremiumWarningDialog: () => jest.fn(),
}))

const mockUseCustomerQuery = jest.fn()
const mockUseSubscriptionQuery = jest.fn()
const mockUseUsageQuery = jest.fn()
const mockUseProjectedUsageQuery = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useCustomerForSubscriptionUsageQuery: (...args: unknown[]) => mockUseCustomerQuery(...args),
  useSubscrptionForSubscriptionUsageQuery: (...args: unknown[]) =>
    mockUseSubscriptionQuery(...args),
  useUsageForSubscriptionUsageQuery: (...args: unknown[]) => mockUseUsageQuery(...args),
  useProjectedUsageForSubscriptionUsageQuery: (...args: unknown[]) =>
    mockUseProjectedUsageQuery(...args),
}))

const mockSubscription = {
  id: 'sub-1',
  name: 'Test Sub',
  status: StatusTypeEnum.Active,
  plan: { id: 'plan-1', name: 'Test Plan', code: 'test-plan' },
  customer: { id: 'customer-1', applicableTimezone: 'TZ_UTC' },
}

const createNoActiveSubscriptionError = () =>
  ({
    graphQLErrors: [
      {
        message: 'NoActiveSubscription',
        extensions: {
          code: LagoApiError.NoActiveSubscription,
        },
      },
    ],
  }) as unknown as ApolloError

const setupDefaultMocks = () => {
  mockUseParams.mockReturnValue({ planId: '' })

  mockUseCustomerQuery.mockReturnValue({
    data: { customer: { id: 'customer-1', applicableTimezone: 'TZ_UTC' } },
    loading: false,
    error: undefined,
  })

  mockUseSubscriptionQuery.mockReturnValue({
    data: { subscription: mockSubscription },
    loading: false,
    error: undefined,
  })

  mockUseProjectedUsageQuery.mockReturnValue({
    data: undefined,
    loading: false,
    error: undefined,
    refetch: jest.fn(),
  })
}

describe('SubscriptionCurrentUsageTable', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    setupDefaultMocks()
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN a NoActiveSubscription error on usage query', () => {
    describe('WHEN customerId is provided', () => {
      it('THEN should show info toast and redirect to customer subscription overview', async () => {
        mockUseUsageQuery.mockReturnValue({
          data: undefined,
          loading: false,
          error: createNoActiveSubscriptionError(),
          refetch: jest.fn(),
        })

        render(
          <AllTheProviders>
            <SubscriptionCurrentUsageTable customerId="customer-1" subscriptionId="sub-1" />
          </AllTheProviders>,
        )

        await waitFor(() => {
          expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'info' }))
        })

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalledWith(
            expect.stringContaining(
              `/customer-1/subscription/sub-1/${CustomerSubscriptionDetailsTabsOptionsEnum.overview}`,
            ),
            { replace: true },
          )
        })
      })
    })

    describe('WHEN customerId is empty (plan context)', () => {
      it('THEN should show info toast and redirect to plan subscription overview', async () => {
        mockUseParams.mockReturnValue({
          planId: 'plan-1',
        })

        mockUseCustomerQuery.mockReturnValue({
          data: undefined,
          loading: false,
          error: undefined,
        })

        mockUseUsageQuery.mockReturnValue({
          data: undefined,
          loading: false,
          error: createNoActiveSubscriptionError(),
          refetch: jest.fn(),
        })

        render(
          <AllTheProviders>
            <SubscriptionCurrentUsageTable customerId="" subscriptionId="sub-1" />
          </AllTheProviders>,
        )

        await waitFor(() => {
          expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'info' }))
        })
      })
    })
  })

  describe('GIVEN a NoActiveSubscription error on projected usage query', () => {
    describe('WHEN the error comes from projected usage', () => {
      it('THEN should show info toast and redirect', async () => {
        mockUseUsageQuery.mockReturnValue({
          data: undefined,
          loading: false,
          error: undefined,
          refetch: jest.fn(),
        })

        mockUseProjectedUsageQuery.mockReturnValue({
          data: undefined,
          loading: false,
          error: createNoActiveSubscriptionError(),
          refetch: jest.fn(),
        })

        render(
          <AllTheProviders>
            <SubscriptionCurrentUsageTable customerId="customer-1" subscriptionId="sub-1" />
          </AllTheProviders>,
        )

        await waitFor(() => {
          expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'info' }))
        })

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalledWith(
            expect.stringContaining(
              `/customer-1/subscription/sub-1/${CustomerSubscriptionDetailsTabsOptionsEnum.overview}`,
            ),
            { replace: true },
          )
        })
      })
    })
  })
})
