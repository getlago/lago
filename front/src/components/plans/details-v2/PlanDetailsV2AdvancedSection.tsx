import { gql } from '@apollo/client'
import { Ref } from 'react'

import { PlanDetailsV2Fragment, PlanForUpdateWithCascadeFragmentDoc } from '~/generated/graphql'

import { EntitlementAccordion, EntitlementAccordionRef } from './accordions/EntitlementAccordion'
import { MinimumCommitmentAccordion } from './accordions/MinimumCommitmentAccordion'
import { ProgressiveBillingAccordion } from './accordions/ProgressiveBillingAccordion'
import { PlanDetailsV2SectionId } from './sidebarSections'

gql`
  fragment PlanForDetailsV2AdvancedSection on Plan {
    ...PlanForUpdateWithCascade
  }

  ${PlanForUpdateWithCascadeFragmentDoc}
`

type PlanDetailsV2AdvancedSectionProps = {
  plan: PlanDetailsV2Fragment
  isInSubscriptionForm?: boolean
  subscriptionId?: string
  entitlementRef?: Ref<EntitlementAccordionRef>
}

export const PlanDetailsV2AdvancedSection = ({
  plan,
  isInSubscriptionForm = false,
  subscriptionId,
  entitlementRef,
}: PlanDetailsV2AdvancedSectionProps) => (
  <section
    id={PlanDetailsV2SectionId.AdvancedSettings}
    className="flex scroll-mt-12 flex-col gap-12 not-last-child:pb-12 not-last-child:shadow-b"
  >
    <MinimumCommitmentAccordion
      plan={plan}
      isInSubscriptionForm={isInSubscriptionForm}
      subscriptionId={subscriptionId}
    />
    {!isInSubscriptionForm && (
      <ProgressiveBillingAccordion plan={plan} isInSubscriptionForm={isInSubscriptionForm} />
    )}
    {!isInSubscriptionForm && (
      <EntitlementAccordion
        ref={entitlementRef}
        plan={plan}
        isInSubscriptionForm={isInSubscriptionForm}
      />
    )}
  </section>
)
