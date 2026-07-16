import { gql } from '@apollo/client'
import { useEffect, useState } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { useCustomerPortalData } from '~/components/customerPortal/common/hooks/useCustomerPortalData'
import useCustomerPortalNavigation from '~/components/customerPortal/common/hooks/useCustomerPortalNavigation'
import PageTitle from '~/components/customerPortal/common/PageTitle'
import SectionTitle from '~/components/customerPortal/common/SectionTitle'
import useCustomerPortalTranslate from '~/components/customerPortal/common/useCustomerPortalTranslate'
import UsageSubscriptionItem from '~/components/customerPortal/usage/UsageSubscriptionItem'
import { Typography } from '~/components/designSystem/Typography'
import {
  SubscriptionCurrentUsageTableComponent,
  UsageData,
} from '~/components/subscriptions/SubscriptionCurrentUsageTable'
import { SubscriptionUsageLifetimeGraphComponent } from '~/components/subscriptions/SubscriptionUsageLifetimeGraph'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { useNavigate } from '~/core/router'
import { CUSTOMER_PORTAL_ROUTE } from '~/core/router/paths/customerPortal'
import {
  CustomerProjectedUsageForUsageDetailsFragmentDoc,
  CustomerUsageForUsageDetailsFragmentDoc,
  LagoApiError,
  PremiumIntegrationTypeEnum,
  SubscriptionCurrentUsageTableComponentCustomerProjectedUsageFragmentDoc,
  SubscriptionCurrentUsageTableComponentCustomerUsageFragmentDoc,
  useGetCustomerProjectedUsageForPortalQuery,
  useGetCustomerUsageForPortalQuery,
  useGetSubscriptionForPortalQuery,
} from '~/generated/graphql'

gql`
  fragment SubscriptionForPortalUsage on Subscription {
    id
    currentBillingPeriodEndingAt
    name

    plan {
      id
      name
      invoiceDisplayName
      code
      amountCents
      amountCurrency
      interval
    }

    customer {
      id
      currency
      applicableTimezone
    }

    lifetimeUsage {
      lastThresholdAmountCents
      nextThresholdAmountCents
      totalUsageAmountCents
      totalUsageFromDatetime
      totalUsageToDatetime
    }
  }

  query getSubscriptionForPortal($subscriptionId: ID!) {
    customerPortalSubscription(id: $subscriptionId) {
      id
      ...SubscriptionForPortalUsage
    }
  }

  query getCustomerUsageForPortal($subscriptionId: ID!) {
    customerPortalCustomerUsage(subscriptionId: $subscriptionId) {
      amountCents
      ...SubscriptionCurrentUsageTableComponentCustomerUsage
      ...CustomerUsageForUsageDetails
    }
  }

  query getCustomerProjectedUsageForPortal($subscriptionId: ID!) {
    customerPortalCustomerProjectedUsage(subscriptionId: $subscriptionId) {
      amountCents
      ...SubscriptionCurrentUsageTableComponentCustomerProjectedUsage
      ...CustomerProjectedUsageForUsageDetails
    }
  }

  ${SubscriptionCurrentUsageTableComponentCustomerUsageFragmentDoc}
  ${SubscriptionCurrentUsageTableComponentCustomerProjectedUsageFragmentDoc}
  ${CustomerUsageForUsageDetailsFragmentDoc}
  ${CustomerProjectedUsageForUsageDetailsFragmentDoc}
`

const UsagePage = () => {
  const { goHome } = useCustomerPortalNavigation()
  const { translate, documentLocale } = useCustomerPortalTranslate()
  const { itemId, token } = useParams()
  const navigate = useNavigate()
  const [activeTab, setActiveTab] = useState<number>(0)

  const showProjected = activeTab === 1

  const subscriptionId = itemId

  const { data: portalData, loading: organizationLoading } = useCustomerPortalData()

  const customerPortalOrganization = portalData?.customerPortalOrganization

  const hasAccessToProjectedUsage = customerPortalOrganization?.premiumIntegrations?.includes(
    PremiumIntegrationTypeEnum.ProjectedUsage,
  )

  const fetchProjected = hasAccessToProjectedUsage && showProjected

  const queryParams = {
    variables: {
      subscriptionId: itemId as string,
    },
    skip: !itemId,
  }

  const {
    data: customerPortalSubscriptionData,
    loading: customerPortalSubscriptionLoading,
    error: customerPortalSubscriptionError,
    refetch: customerPortalSubscriptionRefetch,
  } = useGetSubscriptionForPortalQuery(queryParams)

  const {
    data: usageData,
    loading: usageLoading,
    error: usageError,
    refetch: usageRefetch,
  } = useGetCustomerUsageForPortalQuery({
    ...queryParams,
    skip: queryParams.skip || fetchProjected,
    context: { silentErrorCodes: [LagoApiError.NoActiveSubscription] },
  })

  const {
    data: usageDataProjected,
    loading: usageLoadingProjected,
    error: usageErrorProjected,
    refetch: usageRefetchProjected,
  } = useGetCustomerProjectedUsageForPortalQuery({
    ...queryParams,
    skip: queryParams.skip || !fetchProjected,
    context: { silentErrorCodes: [LagoApiError.NoActiveSubscription] },
  })

  const refetchUsage = (forceProjected?: boolean) =>
    fetchProjected || forceProjected ? usageRefetchProjected() : usageRefetch()

  useEffect(() => {
    if (
      hasDefinedGQLError('NoActiveSubscription', usageError) ||
      hasDefinedGQLError('NoActiveSubscription', usageErrorProjected)
    ) {
      addToast({
        severity: 'info',
        translateKey: 'text_173142196943714qsq737sre',
      })
      navigate(generatePath(CUSTOMER_PORTAL_ROUTE, { token: token as string }), { replace: true })
    }
  }, [usageError, navigate, token, translate, usageErrorProjected])

  const customerPortalSubscription = customerPortalSubscriptionData?.customerPortalSubscription
  const customerId = customerPortalSubscription?.customer?.id

  return (
    <div>
      <PageTitle title={translate('text_1728377307160r73ggjgpulg')} goHome={goHome} />

      <SectionTitle title={translate('text_172837730716038g8qgz927f')} />

      <UsageSubscriptionItem
        subscription={customerPortalSubscription}
        applicableTimezone={customerPortalSubscription?.customer?.applicableTimezone}
        loading={customerPortalSubscriptionLoading}
      />

      {customerId && subscriptionId && customerPortalSubscription?.lifetimeUsage && (
        <div className="mt-12">
          <SubscriptionUsageLifetimeGraphComponent
            subscriptionId={subscriptionId}
            customerId={customerId}
            organization={customerPortalOrganization}
            organizationLoading={organizationLoading}
            subscription={customerPortalSubscription}
            subscriptionLoading={customerPortalSubscriptionLoading}
            subscriptionError={customerPortalSubscriptionError}
            refetchLifetimeData={() => customerPortalSubscriptionRefetch()}
            translate={translate}
            locale={documentLocale}
          />
        </div>
      )}

      {customerId && subscriptionId && (
        <div className="mt-12">
          <SubscriptionCurrentUsageTableComponent
            isUsedinCustomerPortal
            activeTab={activeTab}
            setActiveTab={setActiveTab}
            usageData={
              (usageDataProjected?.customerPortalCustomerProjectedUsage ||
                usageData?.customerPortalCustomerUsage) as UsageData
            }
            usageLoading={usageLoadingProjected || usageLoading}
            usageError={usageErrorProjected || usageError}
            subscription={customerPortalSubscription}
            subscriptionLoading={customerPortalSubscriptionLoading}
            subscriptionError={customerPortalSubscriptionError}
            customerData={customerPortalSubscription?.customer}
            customerLoading={customerPortalSubscriptionLoading}
            customerError={customerPortalSubscriptionError}
            refetchUsage={refetchUsage}
            noUsageOverride={
              <div className="mt-6 flex flex-col gap-3">
                <Typography variant="subhead1" color="grey700">
                  {translate('text_1728384061736ee3wi673knf')}
                </Typography>

                <Typography variant="subhead2" color="grey600">
                  {translate('text_1728384061736kob8d52j62l')}
                </Typography>
              </div>
            }
            translate={translate}
            locale={documentLocale}
            hasAccessToProjectedUsage={hasAccessToProjectedUsage}
          />
        </div>
      )}
    </div>
  )
}

export default UsagePage
