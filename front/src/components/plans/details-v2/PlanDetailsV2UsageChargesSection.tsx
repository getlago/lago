import { gql } from '@apollo/client'
import { forwardRef, useEffect, useImperativeHandle, useMemo, useRef } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import {
  shouldVirtualizeList,
  VirtualFilterList,
  VirtualListApi,
} from '~/components/designSystem/VirtualList/VirtualFilterList'
import {
  UsageChargeDrawer,
  UsageChargeDrawerRef,
} from '~/components/plans/drawers/usageCharge/UsageChargeDrawer'
import {
  RemoveChargeWarningDialog,
  RemoveChargeWarningDialogRef,
} from '~/components/plans/RemoveChargeWarningDialog'
import { LocalUsageChargeInput } from '~/components/plans/types'
import { UsageChargeInfo } from '~/components/plans/UsageChargeInfo'
import { PlanFormProvider } from '~/contexts/PlanFormContext'
import { FORM_ERRORS_ENUM } from '~/core/constants/form'
import { openAccordionThenScrollTo } from '~/core/utils/domUtils'
import {
  CurrencyEnum,
  CustomChargeFragmentDoc,
  GraduatedChargeFragmentDoc,
  GraduatedPercentageChargeFragmentDoc,
  PackageChargeFragmentDoc,
  PercentageChargeFragmentDoc,
  PlanForDetailsV2UsageChargesSectionFragment,
  PlanInterval,
  PresentationGroupKeysFragmentDoc,
  PricingGroupKeysFragmentDoc,
  StandardChargeFragmentDoc,
  TaxForPlanSettingsSectionFragmentDoc,
  TaxForTaxesSelectorSectionFragmentDoc,
  VolumeRangesFragmentDoc,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAccordionPermissions } from '~/hooks/plans/useAccordionPermissions'
import { useCustomPricingUnits } from '~/hooks/plans/useCustomPricingUnits'
import { useSubscriptionPremiumGate } from '~/hooks/plans/useSubscriptionPremiumGate'
import { toLocalUsageChargeInput } from '~/hooks/plans/utils'

import {
  DETAILS_ADD_USAGE_CHARGE_TEST_ID,
  USAGE_CHARGE_ACCORDION_TEST_ID_PREFIX,
  USAGE_CHARGE_EDIT_TEST_ID_PREFIX,
} from './detailsV2TestIds'
import { SectionAccordion } from './shared/SectionAccordion'
import { SectionHeader } from './shared/SectionHeader'
import { PlanDetailsV2SectionId } from './sidebarSections'

gql`
  fragment UsageChargeForDetailsV2 on Charge {
    id
    code
    chargeModel
    invoiceable
    invoiceDisplayName
    minAmountCents
    payInAdvance
    prorated
    regroupPaidFees
    properties {
      graduatedRanges {
        ...GraduatedCharge
      }
      graduatedPercentageRanges {
        ...GraduatedPercentageCharge
      }
      volumeRanges {
        ...VolumeRanges
      }
      ...PackageCharge
      ...StandardCharge
      ...PercentageCharge
      ...CustomCharge
      ...PricingGroupKeys
      ...PresentationGroupKeys
    }
    filters {
      id
      invoiceDisplayName
      values
      properties {
        graduatedRanges {
          ...GraduatedCharge
        }
        graduatedPercentageRanges {
          ...GraduatedPercentageCharge
        }
        volumeRanges {
          ...VolumeRanges
        }
        ...PackageCharge
        ...StandardCharge
        ...PercentageCharge
        ...CustomCharge
        ...PricingGroupKeys
      }
    }
    appliedPricingUnit {
      conversionRate
      pricingUnit {
        id
        name
        code
        shortName
      }
    }
    billableMetric {
      id
      name
      code
      aggregationType
      recurring
      filters {
        id
        key
        values
      }
    }
    taxes {
      ...TaxForTaxesSelectorSection
    }
  }

  fragment PlanForDetailsV2UsageChargesSection on Plan {
    id
    hasOverriddenPlans
    subscriptionsCount
    interval
    amountCurrency
    billChargesMonthly
    taxes {
      ...TaxForPlanSettingsSection
    }
    charges {
      ...UsageChargeForDetailsV2
    }
  }

  ${GraduatedChargeFragmentDoc}
  ${GraduatedPercentageChargeFragmentDoc}
  ${VolumeRangesFragmentDoc}
  ${PackageChargeFragmentDoc}
  ${StandardChargeFragmentDoc}
  ${PercentageChargeFragmentDoc}
  ${CustomChargeFragmentDoc}
  ${PricingGroupKeysFragmentDoc}
  ${PresentationGroupKeysFragmentDoc}
  ${TaxForTaxesSelectorSectionFragmentDoc}
  ${TaxForPlanSettingsSectionFragmentDoc}
`

export type PlanDetailsV2UsageChargesSectionRef = {
  openCreate: () => void
  // Jump-to navigation from the sidebar. When the list is virtualized the target
  // charge may be scrolled out and unmounted, so getElementById alone no-ops; this
  // first brings it into view (scrollToIndex) and opens it, then scrolls + focuses.
  scrollToCharge: (chargeId: string) => void
}

// rAF frame cap (~0.5s at 60fps) for waiting on a virtualized row to mount.
const SCROLL_TO_CHARGE_MAX_FRAMES = 30

export type UsageChargeMutations = {
  handleSaveCharge: (
    charge: LocalUsageChargeInput,
    index: number | null,
  ) => Promise<boolean | FORM_ERRORS_ENUM.existingCode>
  handleDeleteCharge: (chargeId: string) => Promise<boolean>
}

type Props = {
  plan: PlanForDetailsV2UsageChargesSectionFragment
  isInSubscriptionForm?: boolean
  chargeMutations: UsageChargeMutations
}

export const PlanDetailsV2UsageChargesSection = forwardRef<
  PlanDetailsV2UsageChargesSectionRef,
  Props
>(({ plan, isInSubscriptionForm = false, chargeMutations }, ref) => {
  const { translate } = useInternationalization()
  const { canCreate, canUpdate, canDelete } = useAccordionPermissions(isInSubscriptionForm)
  const { gateOnClick, premiumIcon } = useSubscriptionPremiumGate(isInSubscriptionForm)
  const { hasAnyPricingUnitConfigured } = useCustomPricingUnits()
  const drawerRef = useRef<UsageChargeDrawerRef>(null)
  const removeChargeWarningDialogRef = useRef<RemoveChargeWarningDialogRef>(null)

  const { handleSaveCharge, handleDeleteCharge } = chargeMutations

  const planCurrency = plan.amountCurrency
  const charges = plan.charges ?? []
  const isEmpty = charges.length === 0
  // Mirrors VirtualFilterList's internal branch (default threshold) via the shared
  // predicate. Used to drop content-visibility on the cards only when the list
  // actually virtualizes.
  const isChargeListVirtualized = shouldVirtualizeList(charges.length)
  // ISO with the plan form: existing charges lock once the plan has subscriptions.
  // Sub mode keeps its own gating (driven by isInSubscriptionForm), so the
  // subscription-count lock does not apply there.
  const canBeEdited = isInSubscriptionForm ? true : !plan.subscriptionsCount
  // ISO with the plan form: deleting a charge that is live on subscriptions
  // prompts a confirmation. Every listed charge is persisted, so this reduces
  // to "the plan has subscriptions" (canBeEdited === false).
  const isUsedInSubscription = !canBeEdited

  // ISO with the plan form: warn when the same billable metric backs more than
  // one charge (count per BM id, alert when > 1).
  const chargeCountByBillableMetricId = useMemo(() => {
    const counts = new Map<string, number>()

    for (const charge of charges) {
      counts.set(charge.billableMetric.id, (counts.get(charge.billableMetric.id) || 0) + 1)
    }

    return counts
  }, [charges])

  // Charge open state lives in a ref, NOT state: toggling one card must not
  // re-render the section (and thus every other card). Each SectionAccordion keeps
  // its own uncontrolled open state; this ref only mirrors it so the state survives
  // the virtualization unmount/remount cycle - a card reads `initiallyOpen` from the
  // ref on (re)mount and writes back through `onToggle`. Collapsed by default.
  const openChargeIdsRef = useRef<Set<string>>(new Set())
  const virtualListApiRef = useRef<VirtualListApi | null>(null)
  // Handle of the in-flight "wait for the row to mount" loop, so a new jump can
  // supersede a pending one and unmount can cancel it (no orphaned rAF chains).
  const scrollFrameRef = useRef<number>()

  useEffect(() => () => cancelAnimationFrame(scrollFrameRef.current ?? 0), [])

  const openCreate = () => drawerRef.current?.openDrawer()

  const scrollToCharge = (chargeId: string) => {
    const index = charges.findIndex((charge) => charge.id === chargeId)

    if (index < 0) return

    // A new jump supersedes any pending one (rapid sidebar clicks would otherwise
    // leave two loops racing, both calling openAccordionThenScrollTo).
    cancelAnimationFrame(scrollFrameRef.current ?? 0)

    // Mount the card open: a virtualized-out card reads this on (re)mount.
    openChargeIdsRef.current.add(chargeId)

    // Plain branch: the card is already in the DOM, so reuse the shared open-and-scroll
    // (smooth - no virtualized list in the scroll path to derail it).
    if (!virtualListApiRef.current?.isVirtualized) {
      openAccordionThenScrollTo(chargeId)
      return
    }

    // Virtualized branch: bring the row near the viewport so it mounts, then hand off
    // to the shared open-and-scroll once it exists in the DOM.
    virtualListApiRef.current.scrollToIndex(index, { align: 'start' })

    let framesLeft = SCROLL_TO_CHARGE_MAX_FRAMES

    const scrollWhenMounted = () => {
      if (document.getElementById(chargeId)) {
        // Virtualized: scroll instantly so the list's mid-scroll re-measure adjustments
        // can't derail a smooth animation.
        openAccordionThenScrollTo(chargeId, 'auto')

        return
      }

      if (--framesLeft > 0) scrollFrameRef.current = requestAnimationFrame(scrollWhenMounted)
    }

    scrollFrameRef.current = requestAnimationFrame(scrollWhenMounted)
  }

  useImperativeHandle(ref, () => ({ openCreate, scrollToCharge }))

  const openEdit = (charge: LocalUsageChargeInput, index: number) => {
    const alreadyUsedChargeAlertMessage =
      (chargeCountByBillableMetricId.get(charge.billableMetric.id) || 0) > 1
        ? translate('text_6435895831d323008a47911f')
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
    <section id={PlanDetailsV2SectionId.UsageCharges} className="flex scroll-mt-12 flex-col gap-6">
      <SectionHeader
        title={translate('text_1779289915866ngi8sv5t9lg')}
        description={translate('text_6661ffe746c680007e2df0d6')}
        action={
          canCreate
            ? {
                label: translate('text_1772133285142oouequiz2t2'),
                onClick: openCreate,
                startIcon: 'plus',
                dataTest: DETAILS_ADD_USAGE_CHARGE_TEST_ID,
              }
            : undefined
        }
      />

      {isEmpty && (
        <Typography variant="body" color="grey600">
          {translate('text_17797360854699edp5yofy8h')}
        </Typography>
      )}

      {!isEmpty && (
        <VirtualFilterList
          className="flex flex-col gap-6"
          gap={24}
          items={charges}
          // Real collapsed SectionAccordion height (measured in-browser). With the gap
          // VirtualFilterList adds, this matches the measured row height (98px) exactly,
          // so the spacer never shifts as rows measure -> jump-to-section lands first try.
          estimateItemHeight={74}
          getItemKey={(charge) => charge.id}
          apiRef={virtualListApiRef}
          renderItem={(charge, index) => (
            <SectionAccordion
              id={charge.id}
              icon="pulse"
              title={charge.invoiceDisplayName || charge.billableMetric.name}
              subtitle={charge.code}
              disableContentVisibility={isChargeListVirtualized}
              // Virtualized: cap the collapse animation at 250ms. MUI's default
              // timeout:"auto" scales with height (~800ms+ for a huge filter body), and
              // every animation frame makes the outer virtualizer re-measure + relayout
              // the whole charge tail (BIL-205 heavy-close). 250ms keeps a light tween
              // while bounding that frame storm.
              transitionProps={isChargeListVirtualized ? { timeout: 250 } : undefined}
              initiallyOpen={openChargeIdsRef.current.has(charge.id)}
              onToggle={(open) => {
                if (open) openChargeIdsRef.current.add(charge.id)
                else openChargeIdsRef.current.delete(charge.id)
              }}
              dataTest={`${USAGE_CHARGE_ACCORDION_TEST_ID_PREFIX}${index}`}
              actions={[
                {
                  label: translate('text_63e51ef4985f0ebd75c212fc'),
                  startIcon: 'pen',
                  endIcon: premiumIcon,
                  onClick: gateOnClick(() =>
                    openEdit(
                      toLocalUsageChargeInput(charge, planCurrency, hasAnyPricingUnitConfigured),
                      index,
                    ),
                  ),
                  hidden: !canUpdate,
                  dataTest: `${USAGE_CHARGE_EDIT_TEST_ID_PREFIX}${index}`,
                },
                {
                  label: translate('text_63ea0f84f400488553caa786'),
                  startIcon: 'trash',
                  onClick: () => handleDelete(charge.id),
                  hidden: !canDelete,
                },
              ]}
              noContentMargin
            >
              <UsageChargeInfo
                charge={charge}
                currency={plan.amountCurrency as CurrencyEnum}
                planInterval={plan.interval as PlanInterval}
                billChargesMonthly={plan.billChargesMonthly}
                planTaxes={plan.taxes}
              />
            </SectionAccordion>
          )}
        />
      )}

      <PlanFormProvider
        currency={plan.amountCurrency as CurrencyEnum}
        interval={(plan.interval as PlanInterval) ?? PlanInterval.Monthly}
      >
        <UsageChargeDrawer
          ref={drawerRef}
          isEdition
          disabled={!canBeEdited}
          isInSubscriptionForm={isInSubscriptionForm}
          showCode
          existingChargeCodes={charges.map((c) => c.code)}
          amountCurrency={plan.amountCurrency}
          onSave={handleSaveCharge}
          onDelete={(index) => {
            const target = charges[index]

            if (target) handleDeleteCharge(target.id)
          }}
          removeChargeWarningDialogRef={removeChargeWarningDialogRef}
        />
      </PlanFormProvider>

      <RemoveChargeWarningDialog ref={removeChargeWarningDialogRef} />
    </section>
  )
})

PlanDetailsV2UsageChargesSection.displayName = 'PlanDetailsV2UsageChargesSection'
