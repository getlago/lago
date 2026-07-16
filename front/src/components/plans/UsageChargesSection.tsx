import { gql } from '@apollo/client'
import { useStore } from '@tanstack/react-form'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { Selector, SelectorActions } from '~/components/designSystem/Selector'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { VirtualFilterList } from '~/components/designSystem/VirtualList/VirtualFilterList'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import {
  UsageChargeDrawer,
  UsageChargeDrawerRef,
} from '~/components/plans/drawers/usageCharge/UsageChargeDrawer'
import {
  buildChargeHoverActions,
  getFormattedChargeSelectorSubtitle,
  mapChargeIntervalCopy,
} from '~/components/plans/utils'
import { useDuplicatePlanVar } from '~/core/apolloClient/reactiveVars/duplicatePlanVar'
import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { PlanInterval } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { PlanFormType } from '~/hooks/plans/usePlanForm'

import {
  RemoveChargeWarningDialog,
  RemoveChargeWarningDialogRef,
} from './RemoveChargeWarningDialog'
import { LocalUsageChargeInput } from './types'

gql`
  fragment PlanForUsageChargeAccordion on Plan {
    billChargesMonthly
  }
`

// Test ID constants
export const USAGE_CHARGES_ADD_BUTTON_TEST_ID = 'add-usage-charge'

interface UsageChargesSectionProps {
  form: PlanFormType
  alreadyExistingCharges?: LocalUsageChargeInput[] | null
  canBeEdited?: boolean
  isInSubscriptionForm?: boolean
  isEdition: boolean
  subscriptionFormType?: keyof typeof FORM_TYPE_ENUM
}

export const UsageChargesSection = ({
  form,
  alreadyExistingCharges,
  canBeEdited,
  isInSubscriptionForm,
  isEdition,
  subscriptionFormType,
}: UsageChargesSectionProps) => {
  const { translate } = useInternationalization()
  const { type: actionType } = useDuplicatePlanVar()

  // Subscribe to specific slices for granular re-renders
  const charges = useStore(form.store, (s) => s.values.charges)
  const interval = useStore(form.store, (s) => s.values.interval)
  const billChargesMonthly = useStore(form.store, (s) => s.values.billChargesMonthly)
  const amountCurrency = useStore(form.store, (s) => s.values.amountCurrency)

  const hasAnyCharge = !!charges.length
  const removeChargeWarningDialogRef = useRef<RemoveChargeWarningDialogRef>(null)
  const usageChargeDrawerRef = useRef<UsageChargeDrawerRef>(null)
  const [alreadyUsedBmsIds, setAlreadyUsedBmsIds] = useState<Map<string, number>>(new Map())

  const handleDrawerSave = useCallback(
    (charge: LocalUsageChargeInput, index: number | null) => {
      const newCharges = [...form.state.values.charges]

      if (index === null) {
        newCharges.push(charge)
      } else {
        newCharges[index] = charge
      }
      form.setFieldValue('charges', newCharges)
    },
    [form],
  )

  const handleChargeDelete = useCallback(
    (index: number) => {
      const newCharges = [...form.state.values.charges]

      newCharges.splice(index, 1)
      form.setFieldValue('charges', newCharges)
    },
    [form],
  )

  useEffect(() => {
    const BmIdsMap = new Map()

    for (let i = 0; i < charges.length; i++) {
      const element = charges[i]
      const bmId = element.billableMetric.id

      if (BmIdsMap.has(bmId)) {
        BmIdsMap.set(bmId, BmIdsMap.get(bmId) + 1)
      } else {
        BmIdsMap.set(bmId, 1)
      }
    }

    setAlreadyUsedBmsIds(BmIdsMap)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [charges.length])

  const isAnnual = [PlanInterval.Semiannual, PlanInterval.Yearly].includes(interval)

  const intervalBadgeCopy = useMemo(() => {
    return translate(mapChargeIntervalCopy(interval, (isAnnual && !!billChargesMonthly) || false))
  }, [translate, interval, billChargesMonthly, isAnnual])

  if (!hasAnyCharge && isInSubscriptionForm) {
    return null
  }

  const renderChargeSelector = (charge: LocalUsageChargeInput, i: number) => {
    const isNew = !alreadyExistingCharges?.find((chargeFetched) => chargeFetched?.id === charge.id)
    const alreadyUsedChargeAlertMessage =
      (alreadyUsedBmsIds.get(charge.billableMetric.id) || 0) > 1
        ? translate('text_6435895831d323008a47911f')
        : undefined
    const isUsedInSubscription = !isNew && !canBeEdited

    const openUsageChargeDrawer = () => {
      const initialCharge = alreadyExistingCharges?.find(
        (chargeFetched) => chargeFetched?.id === charge.id,
      )

      usageChargeDrawerRef.current?.openDrawer(charge, i, {
        alreadyUsedChargeAlertMessage,
        initialCharge: initialCharge || undefined,
        isUsedInSubscription,
      })
    }

    return (
      <Selector
        data-test={`usage-charge-selector-${i}`}
        icon="pulse"
        key={`usage-charge-${charge.billableMetric.id}-${i}`}
        subtitle={getFormattedChargeSelectorSubtitle({
          chargeModel: charge.chargeModel,
          code: charge.billableMetric.code,
          translate,
        })}
        title={charge.invoiceDisplayName || charge.billableMetric.name}
        endContent={
          <div className="flex items-center gap-3">
            <Chip label={intervalBadgeCopy} />
            <Tooltip placement="top-end" title={translate('text_17719630334671lxunwzo7ae')}>
              <Button icon="chevron-right-filled" variant="quaternary" tabIndex={-1} />
            </Tooltip>
          </div>
        }
        hoverActions={
          <SelectorActions
            actions={buildChargeHoverActions({
              showDelete: !isInSubscriptionForm,
              showWarningOnDelete: actionType !== 'duplicate' && isUsedInSubscription,
              onDelete: () => handleChargeDelete(i),
              onEdit: openUsageChargeDrawer,
              removeChargeWarningDialogRef,
              translate,
            })}
          />
        }
        onClick={() => openUsageChargeDrawer()}
      />
    )
  }

  return (
    <>
      <CenteredPage.PageSection>
        <CenteredPage.PageSectionTitle
          title={translate('text_6435888d7cc86500646d8977')}
          description={translate('text_6661ffe746c680007e2df0d6')}
        />

        {!!hasAnyCharge && (
          <VirtualFilterList
            className="flex flex-col gap-4"
            gap={16}
            items={charges}
            estimateItemHeight={76}
            getItemKey={(charge, i) => `usage-charge-${charge.billableMetric.id}-${i}`}
            renderItem={(charge, i) => renderChargeSelector(charge, i)}
          />
        )}

        {/* Single add button at the bottom */}
        {!isInSubscriptionForm && (
          <Button
            fitContent
            startIcon="plus"
            variant="inline"
            data-test={USAGE_CHARGES_ADD_BUTTON_TEST_ID}
            onClick={() => {
              usageChargeDrawerRef.current?.openDrawer()
            }}
          >
            {translate('text_1772133285142oouequiz2t2')}
          </Button>
        )}
      </CenteredPage.PageSection>

      <UsageChargeDrawer
        ref={usageChargeDrawerRef}
        disabled={isEdition && !canBeEdited}
        isEdition={isEdition}
        isInSubscriptionForm={isInSubscriptionForm}
        subscriptionFormType={subscriptionFormType}
        onSave={handleDrawerSave}
        onDelete={handleChargeDelete}
        removeChargeWarningDialogRef={removeChargeWarningDialogRef}
        amountCurrency={amountCurrency}
      />

      <RemoveChargeWarningDialog ref={removeChargeWarningDialogRef} />
    </>
  )
}

UsageChargesSection.displayName = 'UsageChargesSection'
