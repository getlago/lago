import { gql } from '@apollo/client'

import { CenteredPage } from '~/components/layouts/CenteredPage'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import {
  LagoApiError,
  SubscriptionInformationSectionFragmentDoc,
  SubscriptionInvoiceSectionFragmentDoc,
  SubscriptionPaymentSectionFragmentDoc,
  useGetSubscriptionForDetailsV2OverviewQuery,
} from '~/generated/graphql'

import { SubscriptionInformationSection } from './SubscriptionInformationSection'
import { SubscriptionInvoiceSection } from './SubscriptionInvoiceSection'
import { SubscriptionPaymentSection } from './SubscriptionPaymentSection'

gql`
  query getSubscriptionForDetailsV2Overview($subscriptionId: ID!) {
    subscription(id: $subscriptionId) {
      id
      ...SubscriptionInformationSection
      ...SubscriptionPaymentSection
      ...SubscriptionInvoiceSection
    }
  }

  ${SubscriptionInformationSectionFragmentDoc}
  ${SubscriptionPaymentSectionFragmentDoc}
  ${SubscriptionInvoiceSectionFragmentDoc}
`

type Props = {
  subscriptionId: string
}

export const SubscriptionDetailsV2Overview = ({ subscriptionId }: Props) => {
  const { data, loading } = useGetSubscriptionForDetailsV2OverviewQuery({
    variables: { subscriptionId },
    skip: !subscriptionId,
    context: { silentError: [LagoApiError.NotFound] },
  })

  const subscription = data?.subscription

  if (loading && !subscription) {
    return <DetailsPage.Skeleton />
  }

  if (!subscription) {
    return null
  }

  return (
    <div className="pt-6">
      <CenteredPage.SubsectionWrapper>
        <SubscriptionInformationSection subscription={subscription} />
        <SubscriptionPaymentSection subscription={subscription} />
        <SubscriptionInvoiceSection subscription={subscription} />
      </CenteredPage.SubsectionWrapper>
    </div>
  )
}
