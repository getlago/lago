import { screen } from '@testing-library/react'

import { MainHeaderConfig } from '~/components/MainHeader/types'
import { addToast } from '~/core/apolloClient'
import {
  CUSTOMER_DETAILS_ROUTE,
  SUBSCRIPTIONS_ROUTE,
  UPGRADE_DOWNGRADE_SUBSCRIPTION,
} from '~/core/router'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { StatusTypeEnum } from '~/generated/graphql'
import { render, testMockNavigateFn } from '~/test-utils'

import SubscriptionDetails, {
  SUBSCRIPTION_DETAILS_TERMINATE_TEST_ID,
  SUBSCRIPTION_DETAILS_UPGRADE_DOWNGRADE_TEST_ID,
} from '../SubscriptionDetails'

let capturedConfig: MainHeaderConfig | null = null

jest.mock('~/components/MainHeader/MainHeader', () => ({
  MainHeader: Object.assign(() => null, {
    Configure: (props: MainHeaderConfig) => {
      capturedConfig = props
      return null
    },
  }),
}))

jest.mock('~/components/MainHeader/useMainHeaderTabContent', () => ({
  useMainHeaderTabContent: () => <div data-test="active-tab-content">Tab Content</div>,
}))

const mockHasPermissions = jest.fn().mockReturnValue(true)

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
  }),
}))

const mockUseCurrentUser = jest.fn().mockReturnValue({ isPremium: true })

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => mockUseCurrentUser(),
}))

jest.mock('~/core/utils/copyToClipboard', () => ({
  copyToClipboard: jest.fn(),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

jest.mock('~/hooks/core/useLocationHistory', () => ({
  useLocationHistory: () => ({
    goBack: jest.fn(),
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockOpenTerminateDialog = jest.fn()

jest.mock('~/components/customers/subscriptions/TerminateCustomerSubscriptionDialog', () => ({
  useTerminateCustomerSubscriptionDialog: () => ({
    openTerminateCustomerSubscriptionDialog: mockOpenTerminateDialog,
  }),
}))

jest.mock('~/components/subscriptions/details-v2/SubscriptionDetailsV2Plan', () => ({
  SubscriptionDetailsV2Plan: () => null,
}))

jest.mock('~/components/subscriptions/details-v2/SubscriptionDetailsV2Overview', () => ({
  SubscriptionDetailsV2Overview: () => null,
}))

const mockSubscription = {
  id: 'subscription-1',
  name: 'Test Subscription',
  status: StatusTypeEnum.Active,
  externalId: 'ext-123',
  plan: {
    id: 'plan-1',
    name: 'Test Plan',
    code: 'test-plan',
    payInAdvance: false,
    parent: null,
  },
  customer: {
    id: 'customer-1',
  },
}

const mockUseGetSubscriptionForDetailsQuery = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetSubscriptionForDetailsQuery: () => mockUseGetSubscriptionForDetailsQuery(),
}))

const mockCanEditSubscription = jest.fn().mockReturnValue(true)
const mockIsStatusEditable = jest.fn().mockReturnValue(true)

jest.mock('~/hooks/useSubscriptionPermissionsActions', () => ({
  useSubscriptionPermissionsActions: () => ({
    canEditSubscription: mockCanEditSubscription,
    isStatusEditable: mockIsStatusEditable,
  }),
}))

describe('SubscriptionDetails', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    capturedConfig = null
    mockHasPermissions.mockReturnValue(true)
    mockCanEditSubscription.mockReturnValue(true)
    mockIsStatusEditable.mockReturnValue(true)
    mockUseCurrentUser.mockReturnValue({ isPremium: true })

    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({
      customerId: 'customer-1',
      subscriptionId: 'subscription-1',
    })

    mockUseGetSubscriptionForDetailsQuery.mockReturnValue({
      data: { subscription: mockSubscription },
      loading: false,
      error: null,
    })
  })

  describe('GIVEN the page is rendered with data', () => {
    describe('WHEN in default state', () => {
      it('THEN should configure MainHeader with breadcrumb', () => {
        render(<SubscriptionDetails />)

        expect(capturedConfig?.breadcrumb).toHaveLength(1)
      })

      it('THEN should configure MainHeader with entity', () => {
        render(<SubscriptionDetails />)

        expect(capturedConfig?.entity?.viewName).toBeDefined()
        // metadata is a click-to-copy element wrapping the plan code
        expect(
          (capturedConfig?.entity?.metadata as { props: { children: unknown } })?.props.children,
        ).toBe('test-plan')
      })

      it('THEN should configure MainHeader with a dropdown action', () => {
        render(<SubscriptionDetails />)

        expect(capturedConfig?.actions?.items).toHaveLength(1)
        expect(capturedConfig?.actions?.items[0].type).toBe('dropdown')
      })

      it('THEN should display the active tab content', () => {
        render(<SubscriptionDetails />)

        expect(screen.getByTestId('active-tab-content')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN user does not have subscriptionsUpdate permission', () => {
    beforeEach(() => {
      mockCanEditSubscription.mockReturnValue(false)
    })

    it.each([
      {
        buttonTestId: SUBSCRIPTION_DETAILS_UPGRADE_DOWNGRADE_TEST_ID,
        buttonName: 'upgrade/downgrade',
      },
      {
        buttonTestId: SUBSCRIPTION_DETAILS_TERMINATE_TEST_ID,
        buttonName: 'terminate',
      },
    ])('THEN should hide $buttonName dropdown item', ({ buttonTestId }) => {
      render(<SubscriptionDetails />)

      const dropdownAction = capturedConfig?.actions?.items[0]

      if (dropdownAction?.type === 'dropdown') {
        const item = dropdownAction.items.find((i) => i.dataTest === buttonTestId)

        expect(item?.hidden).toBe(true)
      }
    })
  })

  describe('GIVEN subscription is terminated', () => {
    beforeEach(() => {
      mockUseGetSubscriptionForDetailsQuery.mockReturnValue({
        data: {
          subscription: { ...mockSubscription, status: StatusTypeEnum.Terminated },
        },
        loading: false,
        error: null,
      })
      mockCanEditSubscription.mockReturnValue(false)
    })

    it.each([
      {
        buttonTestId: SUBSCRIPTION_DETAILS_UPGRADE_DOWNGRADE_TEST_ID,
        buttonName: 'upgrade/downgrade',
      },
      {
        buttonTestId: SUBSCRIPTION_DETAILS_TERMINATE_TEST_ID,
        buttonName: 'terminate',
      },
    ])('THEN should hide $buttonName dropdown item', ({ buttonTestId }) => {
      render(<SubscriptionDetails />)

      const dropdownAction = capturedConfig?.actions?.items[0]

      if (dropdownAction?.type === 'dropdown') {
        const item = dropdownAction.items.find((i) => i.dataTest === buttonTestId)

        expect(item?.hidden).toBe(true)
      }
    })
  })

  describe('GIVEN terminating a subscription', () => {
    describe('WHEN customer is NOT deleted', () => {
      it('THEN terminate onClick should call openTerminateCustomerSubscriptionDialog', () => {
        render(<SubscriptionDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          const terminateItem = dropdownAction.items.find(
            (i) => i.dataTest === SUBSCRIPTION_DETAILS_TERMINATE_TEST_ID,
          )

          terminateItem?.onClick(jest.fn())

          expect(mockOpenTerminateDialog).toHaveBeenCalledWith(
            expect.objectContaining({
              id: 'subscription-1',
              name: 'Test Subscription',
              status: StatusTypeEnum.Active,
            }),
          )
        }
      })

      it('THEN the termination callback should navigate to customer details when customer is not deleted', () => {
        render(<SubscriptionDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          const terminateItem = dropdownAction.items.find(
            (i) => i.dataTest === SUBSCRIPTION_DETAILS_TERMINATE_TEST_ID,
          )

          terminateItem?.onClick(jest.fn())

          // Extract the callback from the dialog call
          const dialogArgs = mockOpenTerminateDialog.mock.calls[0][0]

          // Simulate customer NOT deleted (null deletedAt)
          dialogArgs.callback(null)

          expect(testMockNavigateFn).toHaveBeenCalledWith(
            CUSTOMER_DETAILS_ROUTE.replace(':customerId', 'customer-1'),
          )
        }
      })
    })

    describe('WHEN customer is deleted', () => {
      it('THEN the termination callback should navigate to subscriptions list', () => {
        render(<SubscriptionDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          const terminateItem = dropdownAction.items.find(
            (i) => i.dataTest === SUBSCRIPTION_DETAILS_TERMINATE_TEST_ID,
          )

          terminateItem?.onClick(jest.fn())

          const dialogArgs = mockOpenTerminateDialog.mock.calls[0][0]

          // Simulate customer deleted (non-null deletedAt)
          dialogArgs.callback('2024-01-01T00:00:00Z')

          expect(testMockNavigateFn).toHaveBeenCalledWith(SUBSCRIPTIONS_ROUTE)
        }
      })
    })
  })

  describe('GIVEN the page is loading', () => {
    beforeEach(() => {
      mockUseGetSubscriptionForDetailsQuery.mockReturnValue({
        data: null,
        loading: true,
        error: null,
      })
    })

    describe('WHEN the component renders', () => {
      it('THEN should set actionsLoading on MainHeader config', () => {
        render(<SubscriptionDetails />)

        expect(capturedConfig?.actions?.loading).toBe(true)
      })
    })
  })

  describe('GIVEN tab configuration', () => {
    describe('WHEN all conditions are met (premium, permissions, active status)', () => {
      it('THEN should configure 7 tabs', () => {
        render(<SubscriptionDetails />)

        expect(capturedConfig?.tabs).toHaveLength(7)
      })
    })

    describe('WHEN the subscription status is not editable', () => {
      beforeEach(() => {
        mockIsStatusEditable.mockReturnValue(false)
      })

      it('THEN should hide the usage tab', () => {
        render(<SubscriptionDetails />)

        // Usage tab is at index 4
        const usageTab = capturedConfig?.tabs?.[4]

        expect(usageTab?.hidden).toBe(true)
      })
    })

    describe('WHEN user is not premium', () => {
      beforeEach(() => {
        mockUseCurrentUser.mockReturnValue({ isPremium: false })
      })

      it('THEN should hide the activity logs tab', () => {
        render(<SubscriptionDetails />)

        // Activity logs tab is at index 6
        const activityLogsTab = capturedConfig?.tabs?.[6]

        expect(activityLogsTab?.hidden).toBe(true)
      })
    })

    describe('WHEN user does not have auditLogsView permission', () => {
      beforeEach(() => {
        mockHasPermissions.mockReturnValue(false)
      })

      it('THEN should hide the activity logs tab', () => {
        render(<SubscriptionDetails />)

        const activityLogsTab = capturedConfig?.tabs?.[6]

        expect(activityLogsTab?.hidden).toBe(true)
      })
    })

    describe('WHEN subscription has no externalId', () => {
      beforeEach(() => {
        mockUseGetSubscriptionForDetailsQuery.mockReturnValue({
          data: {
            subscription: { ...mockSubscription, externalId: '' },
          },
          loading: false,
          error: null,
        })
      })

      it('THEN should hide the activity logs tab', () => {
        render(<SubscriptionDetails />)

        const activityLogsTab = capturedConfig?.tabs?.[6]

        expect(activityLogsTab?.hidden).toBe(true)
      })
    })
  })

  describe('GIVEN the dropdown actions', () => {
    describe('WHEN clicking the upgrade/downgrade item', () => {
      it('THEN should navigate to the upgrade/downgrade route', () => {
        render(<SubscriptionDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          const upgradeItem = dropdownAction.items.find(
            (i) => i.dataTest === SUBSCRIPTION_DETAILS_UPGRADE_DOWNGRADE_TEST_ID,
          )

          upgradeItem?.onClick(jest.fn())

          expect(testMockNavigateFn).toHaveBeenCalledWith(
            UPGRADE_DOWNGRADE_SUBSCRIPTION.replace(':customerId', 'customer-1').replace(
              ':subscriptionId',
              'subscription-1',
            ),
          )
        }
      })
    })

    describe('WHEN clicking the copy external ID item', () => {
      it('THEN should copy the external ID to clipboard and show toast', () => {
        render(<SubscriptionDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          // Copy external ID item has no dataTest, find it by checking copyToClipboard call
          const copyItem = dropdownAction.items.find((item) => {
            const mockClose = jest.fn()

            item.onClick(mockClose)
            if ((copyToClipboard as jest.Mock).mock.calls.length > 0) {
              return true
            }
            return false
          })

          expect(copyItem).toBeDefined()
          expect(copyToClipboard).toHaveBeenCalledWith('ext-123')
          expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'info' }))
        }
      })
    })
  })

  describe('GIVEN the subscription is accessed from plan context', () => {
    beforeEach(() => {
      const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

      useParamsMock.mockReturnValue({
        planId: 'plan-1',
        subscriptionId: 'subscription-1',
      })
    })

    describe('WHEN the component renders', () => {
      it('THEN should still configure tabs', () => {
        render(<SubscriptionDetails />)

        expect(capturedConfig?.tabs).toHaveLength(7)
      })

      it('THEN should still display the active tab content', () => {
        render(<SubscriptionDetails />)

        expect(screen.getByTestId('active-tab-content')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the v2 tabs', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render the v2 overview tab as visible', () => {
        render(<SubscriptionDetails />)

        const overviewTab = capturedConfig?.tabs?.find(
          (t) => t.title === 'text_628cf761cbe6820138b8f2e4',
        )

        expect(overviewTab).toBeDefined()
        expect(overviewTab?.hidden).toBeFalsy()
      })

      it('THEN should render the subscription plan tab as visible', () => {
        render(<SubscriptionDetails />)

        const subPlanTab = capturedConfig?.tabs?.find(
          (t) => t.title === 'text_17792001643316pbexygvpu2',
        )

        expect(subPlanTab).toBeDefined()
        expect(subPlanTab?.hidden).toBeFalsy()
      })
    })
  })
})
