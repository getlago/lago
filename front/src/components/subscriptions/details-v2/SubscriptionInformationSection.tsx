import { gql } from '@apollo/client'

import { SectionHeader } from '~/components/plans/details-v2/shared/SectionHeader'
import { SubscriptionInformationFields } from '~/components/subscriptions/SubscriptionInformationFields'
import {
  SubscriptionForSubscriptionEditFormFragmentDoc,
  SubscriptionInformationFieldsFragmentDoc,
  SubscriptionInformationSectionFragment,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'

import { useSubscriptionInformationDrawer } from './drawers/useSubscriptionInformationDrawer'

gql`
  fragment SubscriptionInformationSection on Subscription {
    id
    customer {
      id
      applicableTimezone
    }
    ...SubscriptionInformationFields
    ...SubscriptionForSubscriptionEditForm
  }

  ${SubscriptionInformationFieldsFragmentDoc}
  ${SubscriptionForSubscriptionEditFormFragmentDoc}
`

type SubscriptionInformationSectionProps = {
  subscription: SubscriptionInformationSectionFragment
}

export const SubscriptionInformationSection = ({
  subscription,
}: SubscriptionInformationSectionProps) => {
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const { openDrawer } = useSubscriptionInformationDrawer(subscription)

  return (
    <section className="flex flex-col gap-6">
      <SectionHeader
        title={translate('text_6335e8900c69f8ebdfef5312')}
        description={translate('text_66630368f4333b00795b0e1c')}
        action={{
          label: translate('text_63e51ef4985f0ebd75c212fc'),
          startIcon: 'pen',
          onClick: openDrawer,
          hidden: !hasPermissions(['subscriptionsUpdate']),
        }}
      />
      <SubscriptionInformationFields subscription={subscription} />
    </section>
  )
}
