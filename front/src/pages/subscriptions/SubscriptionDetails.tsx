import { gql } from '@apollo/client'
import { useMemo } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { useTerminateCustomerSubscriptionDialog } from '~/components/customers/subscriptions/TerminateCustomerSubscriptionDialog'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { MainHeaderAction } from '~/components/MainHeader/types'
import { useMainHeaderTabContent } from '~/components/MainHeader/useMainHeaderTabContent'
import { SubscriptionDetailsV2Overview } from '~/components/subscriptions/details-v2/SubscriptionDetailsV2Overview'
import { SubscriptionDetailsV2Plan } from '~/components/subscriptions/details-v2/SubscriptionDetailsV2Plan'
import { SubscriptionActivityLogs } from '~/components/subscriptions/SubscriptionActivityLogs'
import { SubscriptionAlertsList } from '~/components/subscriptions/SubscriptionAlertsList'
import { SubscriptionEntitlementsTabContent } from '~/components/subscriptions/SubscriptionEntitlementsTabContent'
import { SubscriptionProgressiveBillingTab } from '~/components/subscriptions/SubscriptionProgressiveBillingTab/SubscriptionProgressiveBillingTab'
import { SubscriptionUsageTabContent } from '~/components/subscriptions/SubscriptionUsageTabContent'
import { addToast } from '~/core/apolloClient'
import { CustomerSubscriptionDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  CREATE_ALERT_CUSTOMER_SUBSCRIPTION_ROUTE,
  CREATE_ALERT_PLAN_SUBSCRIPTION_ROUTE,
  CUSTOMER_DETAILS_ROUTE,
  CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE,
  PLAN_SUBSCRIPTION_DETAILS_ROUTE,
  SUBSCRIPTIONS_ROUTE,
  UPGRADE_DOWNGRADE_SUBSCRIPTION,
  useNavigate,
} from '~/core/router'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import {
  LagoApiError,
  StatusTypeEnum,
  SubscriptionForProgressiveBillingTabFragmentDoc,
  useGetSubscriptionForDetailsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useNotFoundRedirect } from '~/hooks/useNotFoundRedirect'
import { usePermissions } from '~/hooks/usePermissions'
import { useSubscriptionPermissionsActions } from '~/hooks/useSubscriptionPermissionsActions'

gql`
  query getSubscriptionForDetails($subscriptionId: ID!) {
    subscription(id: $subscriptionId) {
      id
      name
      status
      externalId
      plan {
        id
        name
        code
        payInAdvance
        parent {
          id
          name
          code
        }
      }
      customer {
        id
      }
      ...SubscriptionForProgressiveBillingTab
    }
  }

  ${SubscriptionForProgressiveBillingTabFragmentDoc}
`

export const SUBSCRIPTION_DETAILS_ACTIONS_TEST_ID = 'subscription-details-actions'
export const SUBSCRIPTION_DETAILS_UPGRADE_DOWNGRADE_TEST_ID =
  'subscription-details-upgrade-downgrade'
export const SUBSCRIPTION_DETAILS_TERMINATE_TEST_ID = 'subscription-details-terminate'

const SubscriptionDetails = () => {
  const navigate = useNavigate()
  const { isPremium } = useCurrentUser()
  const { hasPermissions } = usePermissions()
  const { canEditSubscription, isStatusEditable } = useSubscriptionPermissionsActions()
  const { planId = '', customerId = '', subscriptionId = '' } = useParams()
  const { translate } = useInternationalization()
  const { openTerminateCustomerSubscriptionDialog } = useTerminateCustomerSubscriptionDialog()
  const {
    data: subscriptionResult,
    loading: isSubscriptionLoading,
    error: subscriptionError,
  } = useGetSubscriptionForDetailsQuery({
    variables: { subscriptionId: subscriptionId as string },
    skip: !subscriptionId,
    context: { silentErrorCodes: [LagoApiError.NotFound] },
  })

  useNotFoundRedirect({
    error: subscriptionError,
    loading: isSubscriptionLoading,
    redirectTo: SUBSCRIPTIONS_ROUTE,
    translateKey: 'text_1777995443788yxv3i6i9276',
  })

  const activeTabContent = useMainHeaderTabContent()

  const subscription = subscriptionResult?.subscription

  const canCreateOrUpdateAlert = useMemo(() => {
    return hasPermissions(['subscriptionsCreate', 'subscriptionsUpdate'])
  }, [hasPermissions])

  const getAlertCreationLink = useMemo(() => {
    if (!isPremium) {
      return `mailto:hello@getlago.com?subject=${translate('text_174652384902646b3ma52uww')}&body=${translate('text_1746523849026ljzi79afhmq')}`
    }

    if (!!customerId) {
      return generatePath(CREATE_ALERT_CUSTOMER_SUBSCRIPTION_ROUTE, {
        customerId,
        subscriptionId,
      })
    }

    return generatePath(CREATE_ALERT_PLAN_SUBSCRIPTION_ROUTE, {
      planId,
      subscriptionId,
    })
  }, [isPremium, customerId, planId, subscriptionId, translate])

  const tabs = useMemo(() => {
    const getCustomerSubscriptionDetailsRoute = (
      tab: CustomerSubscriptionDetailsTabsOptionsEnum,
    ) => {
      return generatePath(CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE, {
        customerId: customerId || '',
        subscriptionId: subscriptionId as string,
        tab,
      })
    }
    const getPlanSubscriptionDetailsRoute = (tab: CustomerSubscriptionDetailsTabsOptionsEnum) => {
      return generatePath(PLAN_SUBSCRIPTION_DETAILS_ROUTE, {
        planId: planId || '',
        subscriptionId: subscriptionId as string,
        tab,
      })
    }

    return [
      {
        title: translate('text_628cf761cbe6820138b8f2e4'),
        link: !!customerId
          ? getCustomerSubscriptionDetailsRoute(CustomerSubscriptionDetailsTabsOptionsEnum.overview)
          : getPlanSubscriptionDetailsRoute(CustomerSubscriptionDetailsTabsOptionsEnum.overview),
        match: [
          getCustomerSubscriptionDetailsRoute(CustomerSubscriptionDetailsTabsOptionsEnum.overview),
          getPlanSubscriptionDetailsRoute(CustomerSubscriptionDetailsTabsOptionsEnum.overview),
        ],
        content: (
          <DetailsPage.Container>
            <SubscriptionDetailsV2Overview subscriptionId={subscriptionId as string} />
          </DetailsPage.Container>
        ),
      },
      {
        title: translate('text_17792001643316pbexygvpu2'),
        link: !!customerId
          ? getCustomerSubscriptionDetailsRoute(
              CustomerSubscriptionDetailsTabsOptionsEnum.subscriptionPlan,
            )
          : getPlanSubscriptionDetailsRoute(
              CustomerSubscriptionDetailsTabsOptionsEnum.subscriptionPlan,
            ),
        match: [
          getCustomerSubscriptionDetailsRoute(
            CustomerSubscriptionDetailsTabsOptionsEnum.subscriptionPlan,
          ),
          getPlanSubscriptionDetailsRoute(
            CustomerSubscriptionDetailsTabsOptionsEnum.subscriptionPlan,
          ),
        ],
        content: (
          <DetailsPage.Container className="pb-0">
            <SubscriptionDetailsV2Plan subscriptionId={subscriptionId as string} />
          </DetailsPage.Container>
        ),
      },
      {
        title: translate('text_1724179887722baucvj7bvc1'),
        link: !!customerId
          ? getCustomerSubscriptionDetailsRoute(
              CustomerSubscriptionDetailsTabsOptionsEnum.progressiveBilling,
            )
          : getPlanSubscriptionDetailsRoute(
              CustomerSubscriptionDetailsTabsOptionsEnum.progressiveBilling,
            ),
        match: [
          getCustomerSubscriptionDetailsRoute(
            CustomerSubscriptionDetailsTabsOptionsEnum.progressiveBilling,
          ),
          getPlanSubscriptionDetailsRoute(
            CustomerSubscriptionDetailsTabsOptionsEnum.progressiveBilling,
          ),
        ],
        // The MainHeader config snapshot strips `content` (ReactNode), so content-only
        // changes don't re-push to context. This tab's content reflects reactive
        // subscription state (progressive billing toggle, threshold reset), so encode
        // those bits in snapshotKey to force a refresh when they change.
        snapshotKey: `${isSubscriptionLoading}-${!!subscription?.progressiveBillingDisabled}-${subscription?.usageThresholds?.length ?? 0}`,
        content: (
          <DetailsPage.Container>
            <SubscriptionProgressiveBillingTab
              subscription={subscription}
              loading={isSubscriptionLoading}
            />
          </DetailsPage.Container>
        ),
      },
      {
        title: translate('text_63e26d8308d03687188221a6'),
        link: !!customerId
          ? getCustomerSubscriptionDetailsRoute(
              CustomerSubscriptionDetailsTabsOptionsEnum.entitlements,
            )
          : getPlanSubscriptionDetailsRoute(
              CustomerSubscriptionDetailsTabsOptionsEnum.entitlements,
            ),
        match: [
          getCustomerSubscriptionDetailsRoute(
            CustomerSubscriptionDetailsTabsOptionsEnum.entitlements,
          ),
          getPlanSubscriptionDetailsRoute(CustomerSubscriptionDetailsTabsOptionsEnum.entitlements),
        ],
        content: (
          <DetailsPage.Container>
            <SubscriptionEntitlementsTabContent />
          </DetailsPage.Container>
        ),
      },
      {
        title: translate('text_1725983967306cei92rkdtvb'),
        link: !!customerId
          ? getCustomerSubscriptionDetailsRoute(CustomerSubscriptionDetailsTabsOptionsEnum.usage)
          : getPlanSubscriptionDetailsRoute(CustomerSubscriptionDetailsTabsOptionsEnum.usage),
        match: [
          getCustomerSubscriptionDetailsRoute(CustomerSubscriptionDetailsTabsOptionsEnum.usage),
          getPlanSubscriptionDetailsRoute(CustomerSubscriptionDetailsTabsOptionsEnum.usage),
        ],
        hidden: !isStatusEditable(subscription?.status),
        content: (
          <DetailsPage.Container>
            <SubscriptionUsageTabContent />
          </DetailsPage.Container>
        ),
      },
      {
        title: translate('text_17465238490269pahbvl3s2m'),
        link: !!customerId
          ? getCustomerSubscriptionDetailsRoute(CustomerSubscriptionDetailsTabsOptionsEnum.alerts)
          : getPlanSubscriptionDetailsRoute(CustomerSubscriptionDetailsTabsOptionsEnum.alerts),
        match: [
          getCustomerSubscriptionDetailsRoute(CustomerSubscriptionDetailsTabsOptionsEnum.alerts),
          getPlanSubscriptionDetailsRoute(CustomerSubscriptionDetailsTabsOptionsEnum.alerts),
        ],
        content: (
          <DetailsPage.Container>
            <SubscriptionAlertsList subscriptionExternalId={subscription?.externalId} />
          </DetailsPage.Container>
        ),
      },
      {
        title: translate('text_1747314141347qq6rasuxisl'),
        link: !!customerId
          ? getCustomerSubscriptionDetailsRoute(
              CustomerSubscriptionDetailsTabsOptionsEnum.activityLogs,
            )
          : getPlanSubscriptionDetailsRoute(
              CustomerSubscriptionDetailsTabsOptionsEnum.activityLogs,
            ),
        match: [
          getCustomerSubscriptionDetailsRoute(
            CustomerSubscriptionDetailsTabsOptionsEnum.activityLogs,
          ),
          getPlanSubscriptionDetailsRoute(CustomerSubscriptionDetailsTabsOptionsEnum.activityLogs),
        ],
        content: (
          <DetailsPage.Container>
            <SubscriptionActivityLogs externalSubscriptionId={subscription?.externalId || ''} />
          </DetailsPage.Container>
        ),
        hidden: !subscription?.externalId || !isPremium || !hasPermissions(['auditLogsView']),
      },
    ]
  }, [
    translate,
    customerId,
    planId,
    subscriptionId,
    subscription,
    isSubscriptionLoading,
    isStatusEditable,
    isPremium,
    hasPermissions,
  ])

  const headerEntity = {
    viewName: translate('text_6529666e71f6ce006d2bf011', {
      planName: subscription?.plan.name,
    }),
    viewNameLoading: isSubscriptionLoading,
    metadata: subscription?.plan.code ? (
      <TypographyWithCopy>{subscription.plan.code}</TypographyWithCopy>
    ) : undefined,
    metadataLoading: isSubscriptionLoading,
  }

  const headerActions: MainHeaderAction[] = [
    {
      type: 'dropdown',
      label: translate('text_626162c62f790600f850b6fe'),
      dataTest: SUBSCRIPTION_DETAILS_ACTIONS_TEST_ID,
      items: [
        {
          label: translate('text_62d7f6178ec94cd09370e64a'),
          dataTest: SUBSCRIPTION_DETAILS_UPGRADE_DOWNGRADE_TEST_ID,
          hidden: !canEditSubscription(subscription?.status),
          onClick: (closePopper) => {
            navigate(
              generatePath(UPGRADE_DOWNGRADE_SUBSCRIPTION, {
                customerId: subscription?.customer?.id as string,
                subscriptionId: subscriptionId as string,
              }),
            )
            closePopper()
          },
        },
        {
          label: translate('text_174652384902646b3ma52uws'),
          hidden: !canCreateOrUpdateAlert,
          onClick: (closePopper) => {
            if (isPremium) {
              navigate(getAlertCreationLink)
            } else {
              window.location.href = getAlertCreationLink
            }
            closePopper()
          },
        },
        {
          label: translate('text_62d7f6178ec94cd09370e65b'),
          onClick: (closePopper) => {
            copyToClipboard(subscription?.externalId || '')

            addToast({
              severity: 'info',
              translateKey: 'text_62d94cc9ccc5eebcc03160a0',
            })
            closePopper()
          },
        },
        {
          label: translate('text_62d904b97e690a881f2b867c'),
          dataTest: SUBSCRIPTION_DETAILS_TERMINATE_TEST_ID,
          hidden: !canEditSubscription(subscription?.status),
          danger: true,
          onClick: (closePopper) => {
            openTerminateCustomerSubscriptionDialog({
              id: subscription?.id as string,
              name: subscription?.name as string,
              status: subscription?.status as StatusTypeEnum,
              payInAdvance: !!subscription?.plan.payInAdvance,
              callback: (deletedAt) => {
                const isCustomerDeleted = !!deletedAt

                if (isCustomerDeleted) {
                  navigate(SUBSCRIPTIONS_ROUTE)
                } else {
                  navigate(
                    generatePath(CUSTOMER_DETAILS_ROUTE, {
                      customerId: subscription?.customer?.id as string,
                    }),
                  )
                }
              },
            })
            closePopper()
          },
        },
      ],
    },
  ]

  return (
    <>
      <MainHeader.Configure
        breadcrumb={[
          { label: translate('text_6250304370f0f700a8fdc28d'), path: SUBSCRIPTIONS_ROUTE },
        ]}
        entity={headerEntity}
        actions={{ items: headerActions, loading: isSubscriptionLoading }}
        tabs={tabs}
      />

      <>{activeTabContent}</>
    </>
  )
}

export default SubscriptionDetails
