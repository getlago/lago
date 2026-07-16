import { useRef } from 'react'

import { Chip } from '~/components/designSystem/Chip'
import { mapCommitmentToDrawerValues } from '~/components/plans/drawers/minimumCommitment/mapToDrawerValues'
import {
  MinimumCommitmentDrawer,
  MinimumCommitmentDrawerRef,
  MinimumCommitmentFormValues,
} from '~/components/plans/drawers/minimumCommitment/MinimumCommitmentDrawer'
import { MinimumCommitmentInfo } from '~/components/plans/MinimumCommitmentInfo'
import { MinimumCommitmentPremiumGate } from '~/components/plans/MinimumCommitmentPremiumGate'
import { mapChargeIntervalCopy } from '~/components/plans/utils'
import { PlanFormProvider } from '~/contexts/PlanFormContext'
import { getIntervalTranslationKey } from '~/core/constants/form'
import { serializeMinimumCommitment } from '~/core/serializers/serializePlanInput'
import { CommitmentTypeEnum, CurrencyEnum, PlanDetailsV2Fragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAccordionPermissions } from '~/hooks/plans/useAccordionPermissions'
import { useSubscriptionPremiumGate } from '~/hooks/plans/useSubscriptionPremiumGate'
import { useUpdatePlanWithCascade } from '~/hooks/plans/useUpdatePlanWithCascade'
import { useUpdateSubscriptionPlanOverride } from '~/hooks/plans/useUpdateSubscriptionPlanOverride'
import { useCurrentUser } from '~/hooks/useCurrentUser'

import { SectionAccordion } from '../shared/SectionAccordion'
import { SectionHeader } from '../shared/SectionHeader'
import { PlanDetailsV2SectionId } from '../sidebarSections'

type MinimumCommitmentAccordionProps = {
  plan: PlanDetailsV2Fragment
  isInSubscriptionForm?: boolean
  subscriptionId?: string
}

export const MinimumCommitmentAccordion = ({
  plan,
  isInSubscriptionForm = false,
  subscriptionId,
}: MinimumCommitmentAccordionProps) => {
  const { translate } = useInternationalization()
  const { isPremium } = useCurrentUser()
  const { canUpdate, canDelete } = useAccordionPermissions(isInSubscriptionForm)
  const { gateOnClick, premiumIcon } = useSubscriptionPremiumGate(isInSubscriptionForm)
  const drawerRef = useRef<MinimumCommitmentDrawerRef>(null)

  const currency = plan.amountCurrency || CurrencyEnum.Usd
  const commitment = plan.minimumCommitment
  const hasCommitment = !!commitment?.amountCents && !isNaN(Number(commitment.amountCents))

  const { form, applyAndSubmit } = useUpdatePlanWithCascade({
    plan,
    includeAdvancedFields: true,
  })
  const { updatePlanOverride } = useUpdateSubscriptionPlanOverride({
    subscriptionId: subscriptionId ?? '',
  })

  const handleSave = (values: MinimumCommitmentFormValues): Promise<boolean> => {
    // Sub mode: route the min-commitment edit through updateSubscription(planOverrides);
    // never call updatePlan, which would mutate the shared base plan (R3).
    if (subscriptionId) {
      return updatePlanOverride({
        minimumCommitment: serializeMinimumCommitment(
          { ...values, commitmentType: CommitmentTypeEnum.MinimumCommitment },
          currency,
        ),
      })
    }

    return applyAndSubmit(() =>
      form.setFieldValue('minimumCommitment', {
        ...values,
        commitmentType: CommitmentTypeEnum.MinimumCommitment,
      }),
    )
  }

  const handleDelete = (): Promise<boolean> => {
    // Sub mode: clear the override via updateSubscription(planOverrides); empty
    // input serializes to {} (matches the plan-tab delete), never calls updatePlan (R3).
    if (subscriptionId) {
      return updatePlanOverride({ minimumCommitment: serializeMinimumCommitment({}, currency) })
    }

    return applyAndSubmit(() => form.setFieldValue('minimumCommitment', {}))
  }

  const openEditDrawer = () =>
    drawerRef.current?.openDrawer(
      mapCommitmentToDrawerValues(commitment, { deserialize: true, currency }),
    )

  const intervalBadge = plan.interval ? (
    <Chip label={translate(getIntervalTranslationKey[plan.interval])} />
  ) : undefined

  return (
    <section
      id={PlanDetailsV2SectionId.MinimumCommitment}
      className="flex scroll-mt-12 flex-col gap-6"
    >
      <SectionHeader
        title={translate('text_65d601bffb11e0f9d1d9f569')}
        description={translate('text_6661fc17337de3591e29e451', {
          interval: translate(mapChargeIntervalCopy(plan.interval, false)).toLocaleLowerCase(),
        })}
        action={{
          label: translate('text_6661ffe746c680007e2df0e1'),
          onClick: () => drawerRef.current?.openDrawer(),
          hidden: hasCommitment || !isPremium,
          startIcon: 'plus',
        }}
      />

      {!isPremium && !hasCommitment && <MinimumCommitmentPremiumGate />}

      {hasCommitment && (
        <SectionAccordion
          icon="minus-circle"
          title={commitment?.invoiceDisplayName || translate('text_65d601bffb11e0f9d1d9f569')}
          badge={intervalBadge}
          actions={[
            {
              label: translate('text_63e51ef4985f0ebd75c212fc'),
              startIcon: 'pen',
              endIcon: premiumIcon,
              onClick: gateOnClick(openEditDrawer),
              hidden: !canUpdate,
            },
            {
              label: translate('text_63ea0f84f400488553caa786'),
              startIcon: 'trash',
              onClick: () => void handleDelete(),
              hidden: !canDelete,
            },
          ]}
        >
          <MinimumCommitmentInfo plan={plan} currency={currency} />
        </SectionAccordion>
      )}

      <PlanFormProvider currency={currency} interval={plan.interval}>
        <MinimumCommitmentDrawer
          ref={drawerRef}
          onSave={handleSave}
          onDelete={() => void handleDelete()}
        />
      </PlanFormProvider>
    </section>
  )
}
