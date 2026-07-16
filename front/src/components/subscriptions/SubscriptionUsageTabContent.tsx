import { gql } from '@apollo/client'
import { useParams } from 'react-router-dom'

import { useGetCustomerFromSubscriptionQuery } from '~/generated/graphql'

import { SubscriptionCurrentUsageTable } from './SubscriptionCurrentUsageTable'
import SubscriptionUsageLifetimeGraph from './SubscriptionUsageLifetimeGraph'

gql`
  query getCustomerFromSubscription($subscriptionId: ID!) {
    subscription(id: $subscriptionId) {
      customer {
        id
      }
    }
  }
`

export const SubscriptionUsageTabContent = () => {
  const { subscriptionId = '' } = useParams()
  let { customerId } = useParams()

  // CustomerId is not provided in PLAN_SUBSCRIPTION_DETAILS_ROUTE,
  // so we need to fetch it from the subscription
  const { data } = useGetCustomerFromSubscriptionQuery({
    variables: {
      subscriptionId,
    },
    skip: !!customerId || !subscriptionId,
  })

  if (data?.subscription?.customer?.id) {
    customerId = data.subscription.customer.id
  }

  return (
    <div className="flex flex-col gap-12 pt-6">
      <SubscriptionUsageLifetimeGraph
        customerId={customerId || ''}
        subscriptionId={subscriptionId}
      />
      <SubscriptionCurrentUsageTable
        customerId={customerId || ''}
        subscriptionId={subscriptionId}
      />
    </div>
  )
}
