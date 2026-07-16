import { gql } from '@apollo/client'
import { forwardRef, useImperativeHandle, useMemo, useRef } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import {
  FixedChargeDrawer,
  FixedChargeDrawerRef,
} from '~/components/plans/drawers/fixedCharge/FixedChargeDrawer'
import { FixedChargeInfo } from '~/components/plans/FixedChargeInfo'
import {
  RemoveChargeWarningDialog,
  RemoveChargeWarningDialogRef,
} from '~/components/plans/RemoveChargeWarningDialog'
import { LocalFixedChargeInput } from '~/components/plans/types'
import { PlanFormProvider } from '~/contexts/PlanFormContext'
import { FORM_ERRORS_ENUM } from '~/core/constants/form'
import {
  CurrencyEnum,
  GraduatedChargeFragmentDoc,
  PlanDetailsV2Fragment,
  PlanInterval,
  TaxForPlanSettingsSectionFragmentDoc,
  VolumeRangesFragmentDoc,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAccordionPermissions } from '~/hooks/plans/useAccordionPermissions'
import { useSubscriptionPremiumGate } from '~/hooks/plans/useSubscriptionPremiumGate'

import { SectionAccordion } from './shared/SectionAccordion'
import { SectionHeader } from './shared/SectionHeader'
import { PlanDetailsV2SectionId } from './sidebarSections'

gql`
  fragment FixedChargeForDetailsV2 on FixedCharge {
    id
    code
    invoiceDisplayName
    chargeModel
    units
    payInAdvance
    prorated
    properties {
      amount
      graduatedRanges {
        ...GraduatedCharge
      }
      volumeRanges {
        ...VolumeRanges
      }
    }
    addOn {
      id
      name
      code
    }
    taxes {
      id
      name
      rate
      code
    }
  }

  fragment PlanForDetailsV2FixedChargesSection on Plan {
    id
    hasOverriddenPlans
    subscriptionsCount
    interval
    amountCurrency
    billFixedChargesMonthly
    taxes {
      ...TaxForPlanSettingsSection
    }
    fixedCharges {
      ...FixedChargeForDetailsV2
    }
  }

  ${GraduatedChargeFragmentDoc}
  ${VolumeRangesFragmentDoc}
  ${TaxForPlanSettingsSectionFragmentDoc}
`

export type PlanDetailsV2FixedChargesSectionRef = {
  openCreate: () => void
}

export type FixedChargeMutations = {
  handleSaveCharge: (
    charge: LocalFixedChargeInput,
    index: number | null,
  ) => Promise<boolean | FORM_ERRORS_ENUM.existingCode>
  handleDeleteCharge: (chargeId: string) => Promise<boolean>
}

type Props = {
  plan: PlanDetailsV2Fragment
  isInSubscriptionForm?: boolean
  fixedChargeMutations: FixedChargeMutations
  // FixedCharge id → units to display when the row is rendered inside a
  // subscription. Set by SubscriptionDetailsV2Plan from
  // Subscription.fixedCharges. Absent in plan-scope rendering.
  subscriptionFixedChargeUnitsById?: Record<string, string>
}

type FixedCharge = NonNullable<PlanDetailsV2Fragment['fixedCharges']>[number]

const toLocalInput = (
  fixedCharge: FixedCharge,
  effectiveUnits: string | null | undefined,
): LocalFixedChargeInput => ({
  id: fixedCharge.id,
  code: fixedCharge.code,
  addOn: fixedCharge.addOn,
  applyUnitsImmediately: false,
  chargeModel: fixedCharge.chargeModel,
  invoiceDisplayName: fixedCharge.invoiceDisplayName ?? '',
  payInAdvance: fixedCharge.payInAdvance ?? false,
  properties: fixedCharge.properties ?? {},
  prorated: fixedCharge.prorated ?? false,
  taxes: fixedCharge.taxes ?? [],
  units: effectiveUnits ? String(effectiveUnits) : '',
})

export const PlanDetailsV2FixedChargesSection = forwardRef<
  PlanDetailsV2FixedChargesSectionRef,
  Props
>((props, ref) => {
  const {
    plan,
    isInSubscriptionForm = false,
    fixedChargeMutations,
    subscriptionFixedChargeUnitsById,
  } = props
  const { translate } = useInternationalization()
  const { canCreate, canUpdate, canDelete } = useAccordionPermissions(isInSubscriptionForm)
  const { gateOnClick, premiumIcon } = useSubscriptionPremiumGate(isInSubscriptionForm)
  const drawerRef = useRef<FixedChargeDrawerRef>(null)
  const removeChargeWarningDialogRef = useRef<RemoveChargeWarningDialogRef>(null)

  const { handleSaveCharge, handleDeleteCharge } = fixedChargeMutations

  const fixedCharges = plan.fixedCharges ?? []
  const isEmpty = fixedCharges.length === 0
  // ISO with the plan form: existing charges lock once the plan has subscriptions.
  // Sub mode keeps its own gating (driven by isInSubscriptionForm), so the
  // subscription-count lock does not apply there.
  const canBeEdited = isInSubscriptionForm ? true : !plan.subscriptionsCount
  // ISO with the plan form: deleting a charge that is live on subscriptions
  // prompts a confirmation. Every listed charge is persisted, so this reduces
  // to "the plan has subscriptions" (canBeEdited === false).
  const isUsedInSubscription = !canBeEdited

  // ISO with the plan form: warn when the same add-on backs more than one fixed
  // charge (count per add-on id, alert when > 1).
  const fixedChargeCountByAddOnId = useMemo(() => {
    const counts = new Map<string, number>()

    for (const fixedCharge of fixedCharges) {
      counts.set(fixedCharge.addOn.id, (counts.get(fixedCharge.addOn.id) || 0) + 1)
    }

    return counts
  }, [fixedCharges])

  const openCreate = () => drawerRef.current?.openDrawer()

  useImperativeHandle(ref, () => ({ openCreate }))

  const openEdit = (charge: LocalFixedChargeInput, index: number) => {
    const alreadyUsedChargeAlertMessage =
      (fixedChargeCountByAddOnId.get(charge.addOn.id) || 0) > 1
        ? translate('text_1760729707268h378x60alri')
        : undefined

    drawerRef.current?.openDrawer(charge, index, {
      alreadyUsedChargeAlertMessage,
      isUsedInSubscription,
    })
  }

  // ISO with the plan form: confirm before deleting a charge that is live on
  // subscriptions; delete directly otherwise.
  const handleDelete = (chargeId: string) => {
    if (isUsedInSubscription) {
      removeChargeWarningDialogRef.current?.openDialog({
        callback: () => handleDeleteCharge(chargeId),
      })
    } else {
      handleDeleteCharge(chargeId)
    }
  }

  return (
    <section id={PlanDetailsV2SectionId.FixedCharges} className="flex scroll-mt-12 flex-col gap-6">
      <SectionHeader
        title={translate('text_1779289915866aj39dyv1wps')}
        description={translate('text_1760729707268c05r06ip8vg')}
        action={
          canCreate
            ? {
                label: translate('text_176072970726882uau5y69f1'),
                onClick: openCreate,
                startIcon: 'plus',
              }
            : undefined
        }
      />

      {isEmpty && (
        <Typography variant="body" color="grey600">
          {translate('text_1779477955768bq18jsqhaom')}
        </Typography>
      )}

      {fixedCharges.map((fixedCharge, index) => {
        // In subscription mode, prefer the per-subscription override; otherwise
        // fall back to the plan default carried on FixedCharge.units.
        const effectiveUnits =
          subscriptionFixedChargeUnitsById?.[fixedCharge.id] ?? fixedCharge.units

        return (
          <SectionAccordion
            key={fixedCharge.id}
            id={fixedCharge.id}
            icon="puzzle"
            title={fixedCharge.invoiceDisplayName || fixedCharge.addOn.name}
            subtitle={fixedCharge.code}
            actions={[
              {
                label: translate('text_63e51ef4985f0ebd75c212fc'),
                startIcon: 'pen',
                endIcon: premiumIcon,
                onClick: gateOnClick(() =>
                  openEdit(toLocalInput(fixedCharge, effectiveUnits), index),
                ),
                hidden: !canUpdate,
              },
              {
                label: translate('text_63ea0f84f400488553caa786'),
                startIcon: 'trash',
                onClick: () => handleDelete(fixedCharge.id),
                hidden: !canDelete,
              },
            ]}
            noContentMargin
          >
            <FixedChargeInfo
              fixedCharge={{ ...fixedCharge, units: effectiveUnits }}
              currency={plan.amountCurrency as CurrencyEnum}
              planInterval={plan.interval as PlanInterval}
              billFixedChargesMonthly={plan.billFixedChargesMonthly}
              planTaxes={plan.taxes}
            />
          </SectionAccordion>
        )
      })}

      <PlanFormProvider
        currency={plan.amountCurrency as CurrencyEnum}
        interval={(plan.interval as PlanInterval) ?? PlanInterval.Monthly}
      >
        <FixedChargeDrawer
          ref={drawerRef}
          isEdition
          disabled={!canBeEdited}
          isInSubscriptionForm={isInSubscriptionForm}
          showCode
          existingChargeCodes={fixedCharges.map((c) => c.code)}
          onSave={handleSaveCharge}
          onDelete={(index) => {
            const target = fixedCharges[index]

            if (target) handleDeleteCharge(target.id)
          }}
          removeChargeWarningDialogRef={removeChargeWarningDialogRef}
        />
      </PlanFormProvider>

      <RemoveChargeWarningDialog ref={removeChargeWarningDialogRef} />
    </section>
  )
})

PlanDetailsV2FixedChargesSection.displayName = 'PlanDetailsV2FixedChargesSection'
