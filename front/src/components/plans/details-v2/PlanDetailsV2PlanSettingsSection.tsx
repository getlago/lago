import { gql } from '@apollo/client'

import { usePlanSettingsDrawer } from '~/components/plans/drawers/planSettings/usePlanSettingsDrawer'
import { PlanSettingsInfo } from '~/components/plans/PlanSettingsInfo'
import {
  PlanDetailsV2Fragment,
  PlanForDetailsV2SubscriptionFeeAccordionFragmentDoc,
  PlanForUpdateWithCascadeFragmentDoc,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAccordionPermissions } from '~/hooks/plans/useAccordionPermissions'
import { useSubscriptionPremiumGate } from '~/hooks/plans/useSubscriptionPremiumGate'

import { PLAN_SETTINGS_ACCORDION_TEST_ID, PLAN_SETTINGS_EDIT_TEST_ID } from './detailsV2TestIds'
import { SectionAccordion } from './shared/SectionAccordion'
import { SectionHeader } from './shared/SectionHeader'
import { PlanDetailsV2SectionId } from './sidebarSections'
import { SubscriptionFeeAccordion } from './SubscriptionFeeAccordion'

gql`
  fragment PlanForDetailsV2PlanSettingsSection on Plan {
    subscriptionsCount
    ...PlanForUpdateWithCascade
    ...PlanForDetailsV2SubscriptionFeeAccordion
  }

  ${PlanForUpdateWithCascadeFragmentDoc}
  ${PlanForDetailsV2SubscriptionFeeAccordionFragmentDoc}
`

type PlanDetailsV2PlanSettingsSectionProps = {
  plan: PlanDetailsV2Fragment
  isInSubscriptionForm?: boolean
  subscriptionId?: string
}

export const PlanDetailsV2PlanSettingsSection = ({
  plan,
  isInSubscriptionForm = false,
  subscriptionId,
}: PlanDetailsV2PlanSettingsSectionProps) => {
  const { translate } = useInternationalization()
  const { canUpdate } = useAccordionPermissions(isInSubscriptionForm)
  const { gateOnClick, premiumIcon } = useSubscriptionPremiumGate(isInSubscriptionForm)
  const { openDrawer } = usePlanSettingsDrawer(plan, subscriptionId)

  return (
    <section id={PlanDetailsV2SectionId.PlanSettings} className="flex scroll-mt-12 flex-col gap-6">
      <SectionHeader
        title={translate('text_642d5eb2783a2ad10d67031a')}
        description={translate('text_6661fc17337de3591e29e3c1')}
      />
      <SectionAccordion
        title={translate('text_642d5eb2783a2ad10d67031a')}
        dataTest={PLAN_SETTINGS_ACCORDION_TEST_ID}
        actions={[
          {
            label: translate('text_63e51ef4985f0ebd75c212fc'),
            startIcon: 'pen',
            endIcon: premiumIcon,
            onClick: gateOnClick(openDrawer),
            hidden: !canUpdate,
            dataTest: PLAN_SETTINGS_EDIT_TEST_ID,
          },
        ]}
      >
        <PlanSettingsInfo plan={plan} />
      </SectionAccordion>

      <SubscriptionFeeAccordion
        plan={plan}
        isInSubscriptionForm={isInSubscriptionForm}
        subscriptionId={subscriptionId}
      />
    </section>
  )
}
