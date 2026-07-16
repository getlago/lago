import { gql } from '@apollo/client'

import { DetailsPage } from '~/components/layouts/DetailsPage'
import {
  SubscriptionForSubscriptionInformationsFragment,
  SubscriptionInformationFieldsFragmentDoc,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { SubscriptionInformationFields } from './SubscriptionInformationFields'

export { SubscriptionDowngradeAlert } from './SubscriptionInformationFields'

gql`
  fragment SubscriptionForSubscriptionInformations on Subscription {
    id
    ...SubscriptionInformationFields
  }

  ${SubscriptionInformationFieldsFragmentDoc}
`

export const SubscriptionInformations = ({
  subscription,
}: {
  subscription?: SubscriptionForSubscriptionInformationsFragment | null
}) => {
  const { translate } = useInternationalization()

  return (
    <section>
      <DetailsPage.SectionTitle variant="subhead1" noWrap>
        {translate('text_6335e8900c69f8ebdfef5312')}
      </DetailsPage.SectionTitle>
      <SubscriptionInformationFields subscription={subscription} />
    </section>
  )
}
