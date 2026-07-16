import { render as rtlRender, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import {
  GetCustomerIdForActivityLogDetailsDocument,
  GetSingleActivityLogDocument,
  GetSubscriptionIdForActivityLogDetailsDocument,
} from '~/generated/graphql'
import { AllTheProviders, TestMocksType } from '~/test-utils'

import {
  ACTIVITY_LOG_DETAILS_CLOSE_BUTTON_TEST_ID,
  ACTIVITY_LOG_DETAILS_CONTENT_TEST_ID,
  ACTIVITY_LOG_DETAILS_CUSTOMER_LINK_TEST_ID,
  ACTIVITY_LOG_DETAILS_LOADING_TEST_ID,
  ACTIVITY_LOG_DETAILS_SUBSCRIPTION_LINK_TEST_ID,
  ActivityLogDetails,
} from '../ActivityLogDetails'

const mockSetMainRouterUrl = jest.fn()
const mockClosePanel = jest.fn()

jest.mock('~/hooks/useDeveloperTool', () => ({
  DEVTOOL_TAB_PARAMS: 'devtool-tab',
  useDeveloperTool: () => ({
    setMainRouterUrl: mockSetMainRouterUrl,
    closePanel: mockClosePanel,
    mainRouterUrl: '',
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/helpers/useFormatterDateHelper', () => ({
  useFormatterDateHelper: () => ({
    formattedDateTimeWithSecondsOrgaTZ: (date: string) => date,
  }),
}))

jest.mock('~/hooks/activityLogs/useActivityLogsInformation', () => ({
  useActivityLogsInformation: () => ({
    getActivityDescription: () => 'Test activity description',
    getResourceType: (typename: string) => typename,
  }),
}))

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useParams: () => ({ logId: 'test-log-id' }),
}))

const mockActivityLog = {
  __typename: 'ActivityLog' as const,
  activityId: 'activity-123',
  activityType: 'plan_created',
  activitySource: 'api',
  activityObject: { name: 'Test Plan' },
  activityObjectChanges: { name: ['Old', 'New'] },
  loggedAt: '2026-04-20T10:00:00Z',
  userEmail: 'user@test.com',
  externalSubscriptionId: 'ext-sub-123',
  externalCustomerId: 'ext-cust-123',
  apiKey: { __typename: 'SanitizedApiKey' as const, value: 'key-value', name: 'Test Key' },
  resource: {
    __typename: 'Plan' as const,
    id: 'plan-456',
  },
}

const buildActivityLogMock = (overrides: Partial<typeof mockActivityLog> = {}): TestMocksType => [
  {
    request: {
      query: GetSingleActivityLogDocument,
      variables: { id: 'test-log-id' },
    },
    result: {
      data: {
        activityLog: {
          ...mockActivityLog,
          ...overrides,
        },
      },
    },
  },
]

const buildCustomerMock = (customerId: string | null = 'customer-internal-123'): TestMocksType => [
  {
    request: {
      query: GetCustomerIdForActivityLogDetailsDocument,
      variables: { externalId: 'ext-cust-123' },
    },
    result: {
      data: {
        customer: customerId ? { __typename: 'Customer' as const, id: customerId } : null,
      },
    },
  },
]

const buildSubscriptionMock = (
  subscriptionId: string | null = 'subscription-internal-123',
): TestMocksType => [
  {
    request: {
      query: GetSubscriptionIdForActivityLogDetailsDocument,
      variables: { externalId: 'ext-sub-123' },
    },
    result: {
      data: {
        subscription: subscriptionId
          ? { __typename: 'Subscription' as const, id: subscriptionId }
          : null,
      },
    },
  },
]

const renderComponent = (mocks: TestMocksType = []) =>
  rtlRender(
    <AllTheProviders mocks={mocks} forceTypenames>
      <ActivityLogDetails goBack={mockGoBack} />
    </AllTheProviders>,
  )

const mockGoBack = jest.fn()

describe('ActivityLogDetails', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the data is loading', () => {
    describe('WHEN the component renders', () => {
      it('THEN should display loading skeletons', () => {
        renderComponent([])

        expect(screen.getByTestId(ACTIVITY_LOG_DETAILS_LOADING_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId(ACTIVITY_LOG_DETAILS_CONTENT_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the data has loaded', () => {
    describe('WHEN the component renders with activity log data', () => {
      it('THEN should display content and not loading state', async () => {
        renderComponent([
          ...buildActivityLogMock(),
          ...buildCustomerMock(),
          ...buildSubscriptionMock(),
        ])

        await waitFor(() => {
          expect(screen.getByTestId(ACTIVITY_LOG_DETAILS_CONTENT_TEST_ID)).toBeInTheDocument()
        })

        expect(screen.queryByTestId(ACTIVITY_LOG_DETAILS_LOADING_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN the close button is clicked', () => {
      it('THEN should call goBack', async () => {
        const user = userEvent.setup()

        renderComponent([
          ...buildActivityLogMock(),
          ...buildCustomerMock(),
          ...buildSubscriptionMock(),
        ])

        await waitFor(() => {
          expect(screen.getByTestId(ACTIVITY_LOG_DETAILS_CONTENT_TEST_ID)).toBeInTheDocument()
        })

        const closeButton = screen.getByTestId(ACTIVITY_LOG_DETAILS_CLOSE_BUTTON_TEST_ID)

        await user.click(closeButton)

        expect(mockGoBack).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN the customer link button is clicked', () => {
      it('THEN should call setMainRouterUrl and closePanel', async () => {
        const user = userEvent.setup()

        renderComponent([
          ...buildActivityLogMock(),
          ...buildCustomerMock('customer-internal-123'),
          ...buildSubscriptionMock(),
        ])

        await waitFor(() => {
          expect(screen.getByTestId(ACTIVITY_LOG_DETAILS_CUSTOMER_LINK_TEST_ID)).toBeInTheDocument()
        })

        const customerLink = screen.getByTestId(ACTIVITY_LOG_DETAILS_CUSTOMER_LINK_TEST_ID)

        await user.click(customerLink)

        expect(mockSetMainRouterUrl).toHaveBeenCalledWith(
          expect.stringContaining('customer-internal-123'),
        )
        expect(mockClosePanel).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN the subscription link button is clicked', () => {
      it('THEN should call setMainRouterUrl and closePanel', async () => {
        const user = userEvent.setup()

        renderComponent([
          ...buildActivityLogMock(),
          ...buildCustomerMock('customer-internal-123'),
          ...buildSubscriptionMock('subscription-internal-123'),
        ])

        await waitFor(() => {
          expect(
            screen.getByTestId(ACTIVITY_LOG_DETAILS_SUBSCRIPTION_LINK_TEST_ID),
          ).toBeInTheDocument()
        })

        const subscriptionLink = screen.getByTestId(ACTIVITY_LOG_DETAILS_SUBSCRIPTION_LINK_TEST_ID)

        await user.click(subscriptionLink)

        expect(mockSetMainRouterUrl).toHaveBeenCalledWith(
          expect.stringContaining('subscription-internal-123'),
        )
        expect(mockClosePanel).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN customer data is not available', () => {
      it('THEN should not display the customer link button', async () => {
        renderComponent([
          ...buildActivityLogMock(),
          ...buildCustomerMock(null),
          ...buildSubscriptionMock(),
        ])

        await waitFor(() => {
          expect(screen.getByTestId(ACTIVITY_LOG_DETAILS_CONTENT_TEST_ID)).toBeInTheDocument()
        })

        expect(
          screen.queryByTestId(ACTIVITY_LOG_DETAILS_CUSTOMER_LINK_TEST_ID),
        ).not.toBeInTheDocument()
      })
    })

    describe('WHEN subscription data is not available', () => {
      it('THEN should not display the subscription link button', async () => {
        renderComponent([
          ...buildActivityLogMock(),
          ...buildCustomerMock(),
          ...buildSubscriptionMock(null),
        ])

        await waitFor(() => {
          expect(screen.getByTestId(ACTIVITY_LOG_DETAILS_CONTENT_TEST_ID)).toBeInTheDocument()
        })

        expect(
          screen.queryByTestId(ACTIVITY_LOG_DETAILS_SUBSCRIPTION_LINK_TEST_ID),
        ).not.toBeInTheDocument()
      })
    })
  })
})
