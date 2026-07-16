import { gql } from '@apollo/client'
import { useRef } from 'react'

import { Chip } from '~/components/designSystem/Chip'
import {
  SubscriptionFeeDrawer,
  SubscriptionFeeDrawerRef,
  SubscriptionFeeFormValues,
} from '~/components/plans/drawers/subscriptionFee/SubscriptionFeeDrawer'
import { SubscriptionFeeInfo } from '~/components/plans/SubscriptionFeeInfo'
import { PlanFormProvider } from '~/contexts/PlanFormContext'
import { FORM_TYPE_ENUM, getIntervalTranslationKey } from '~/core/constants/form'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount, serializeAmount } from '~/core/serializers/serializeAmount'
import {
  CurrencyEnum,
  PlanDetailsV2Fragment,
  PlanForUpdateWithCascadeFragmentDoc,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAccordionPermissions } from '~/hooks/plans/useAccordionPermissions'
import { useSubscriptionPremiumGate } from '~/hooks/plans/useSubscriptionPremiumGate'
import { useUpdatePlanWithCascade } from '~/hooks/plans/useUpdatePlanWithCascade'
import { useUpdateSubscriptionPlanOverride } from '~/hooks/plans/useUpdateSubscriptionPlanOverride'

import {
  SUBSCRIPTION_FEE_ACCORDION_TEST_ID,
  SUBSCRIPTION_FEE_EDIT_TEST_ID,
} from './detailsV2TestIds'
import { SectionAccordion } from './shared/SectionAccordion'
import { PlanDetailsV2SectionId } from './sidebarSections'

gql`
  fragment PlanForDetailsV2SubscriptionFeeAccordion on Plan {
    subscriptionsCount
    amountCents
    payInAdvance
    trialPeriod
    invoiceDisplayName
    interval
    amountCurrency
    ...PlanForUpdateWithCascade
  }

  ${PlanForUpdateWithCascadeFragmentDoc}
`

type SubscriptionFeeAccordionProps = {
  plan: PlanDetailsV2Fragment
  isInSubscriptionForm?: boolean
  subscriptionId?: string
}

export const SubscriptionFeeAccordion = ({
  plan,
  isInSubscriptionForm = false,
  subscriptionId,
}: SubscriptionFeeAccordionProps) => {
  const { translate } = useInternationalization()
  const { canUpdate } = useAccordionPermissions(isInSubscriptionForm)
  const { gateOnClick, premiumIcon } = useSubscriptionPremiumGate(isInSubscriptionForm)
  const drawerRef = useRef<SubscriptionFeeDrawerRef>(null)

  // ISO with the plan form: payInAdvance + trialPeriod lock once the plan has
  // subscriptions. Sub mode keeps its own gating (isInSubscriptionForm +
  // subscriptionFormType), so the subscription-count lock does not apply there.
  const canBeEdited = subscriptionId ? true : !plan.subscriptionsCount
  const subscriptionFormType = subscriptionId ? FORM_TYPE_ENUM.edition : undefined

  const { form, submit } = useUpdatePlanWithCascade({ plan })
  const { updatePlanOverride } = useUpdateSubscriptionPlanOverride({
    subscriptionId: subscriptionId ?? '',
  })

  const currency = plan.amountCurrency || CurrencyEnum.Usd
  const formattedAmount = intlFormatNumber(deserializeAmount(plan.amountCents || 0, currency), {
    currency,
  })

  const openDrawer = () => {
    drawerRef.current?.openDrawer({
      // plan.amountCents is serialized (cents) from the API; the drawer input
      // edits display units, so deserialize first (the plan-form path already
      // holds display units in its form store, hence the difference).
      amountCents:
        plan.amountCents !== null && plan.amountCents !== undefined
          ? String(deserializeAmount(plan.amountCents, currency))
          : '',
      payInAdvance: plan.payInAdvance ?? false,
      trialPeriod: plan.trialPeriod ?? 0,
      invoiceDisplayName: plan.invoiceDisplayName ?? undefined,
    })
  }

  const handleDrawerSave = async (values: SubscriptionFeeFormValues): Promise<boolean> => {
    // Sub mode: route the plan-level fee edit through updateSubscription(planOverrides);
    // never call updatePlan, which would mutate the shared base plan (R3).
    // payInAdvance + trialPeriod are disabled in the sub drawer and intentionally not sent here.
    if (subscriptionId) {
      return updatePlanOverride({
        amountCents: Number(serializeAmount(values.amountCents, plan.amountCurrency)),
        invoiceDisplayName: values.invoiceDisplayName || undefined,
      })
    }

    form.setFieldValue('amountCents', values.amountCents)
    form.setFieldValue('payInAdvance', values.payInAdvance)
    form.setFieldValue('trialPeriod', values.trialPeriod)
    form.setFieldValue('invoiceDisplayName', values.invoiceDisplayName)
    return submit()
  }

  const intervalBadge = plan.interval ? (
    <Chip label={translate(getIntervalTranslationKey[plan.interval])} />
  ) : undefined

  return (
    <>
      <SectionAccordion
        id={PlanDetailsV2SectionId.SubscriptionFee}
        title={plan.invoiceDisplayName || translate('text_642d5eb2783a2ad10d670336')}
        subtitle={formattedAmount}
        badge={intervalBadge}
        dataTest={SUBSCRIPTION_FEE_ACCORDION_TEST_ID}
        actions={[
          {
            label: translate('text_63e51ef4985f0ebd75c212fc'),
            startIcon: 'pen',
            endIcon: premiumIcon,
            onClick: gateOnClick(openDrawer),
            hidden: !canUpdate,
            dataTest: SUBSCRIPTION_FEE_EDIT_TEST_ID,
          },
        ]}
      >
        <SubscriptionFeeInfo plan={plan} />
      </SectionAccordion>

      <PlanFormProvider currency={plan.amountCurrency} interval={plan.interval}>
        <SubscriptionFeeDrawer
          ref={drawerRef}
          onSave={handleDrawerSave}
          isEdition
          canBeEdited={canBeEdited}
          isInSubscriptionForm={isInSubscriptionForm}
          subscriptionFormType={subscriptionFormType}
        />
      </PlanFormProvider>
    </>
  )
}
