import { gql } from '@apollo/client'
import { ReactNode, useMemo, useRef } from 'react'

import { shouldVirtualizeList } from '~/components/designSystem/VirtualList/VirtualFilterList'
import { openAccordionThenScrollTo } from '~/core/utils/domUtils'
import {
  EntitlementForPlanDetailsSidebarFragmentDoc,
  FixedChargeForPlanDetailsSidebarFragmentDoc,
  LagoApiError,
  PlanForDetailsV2AdvancedSectionFragmentDoc,
  PlanForDetailsV2FixedChargesSectionFragmentDoc,
  PlanForDetailsV2PlanSettingsSectionFragmentDoc,
  PlanForDetailsV2UsageChargesSectionFragmentDoc,
  UsageChargeForPlanDetailsSidebarFragmentDoc,
  useGetPlanForDetailsV2Query,
} from '~/generated/graphql'
import { useDetailsV2ChargeMutations } from '~/hooks/plans/useDetailsV2ChargeMutations'
import { useSubscriptionPremiumGate } from '~/hooks/plans/useSubscriptionPremiumGate'
import { tw } from '~/styles/utils'

import { EntitlementAccordionRef } from './accordions/EntitlementAccordion'
import { PlanDetailsV2AdvancedSection } from './PlanDetailsV2AdvancedSection'
import {
  PlanDetailsV2FixedChargesSection,
  PlanDetailsV2FixedChargesSectionRef,
} from './PlanDetailsV2FixedChargesSection'
import { PlanDetailsV2LeftSidebar } from './PlanDetailsV2LeftSidebar'
import { PlanDetailsV2PlanSettingsSection } from './PlanDetailsV2PlanSettingsSection'
import { PlanDetailsV2Skeleton } from './PlanDetailsV2Skeleton'
import {
  PlanDetailsV2UsageChargesSection,
  PlanDetailsV2UsageChargesSectionRef,
} from './PlanDetailsV2UsageChargesSection'
import { PlanDetailsV2SectionId } from './sidebarSections'

gql`
  fragment PlanDetailsV2 on Plan {
    id
    fixedCharges {
      ...FixedChargeForPlanDetailsSidebar
    }
    charges {
      ...UsageChargeForPlanDetailsSidebar
    }
    entitlements {
      ...EntitlementForPlanDetailsSidebar
    }
    ...PlanForDetailsV2PlanSettingsSection
    ...PlanForDetailsV2FixedChargesSection
    ...PlanForDetailsV2UsageChargesSection
    ...PlanForDetailsV2AdvancedSection
  }

  query getPlanForDetailsV2($planId: ID!) {
    plan(id: $planId) {
      ...PlanDetailsV2
    }
  }

  ${FixedChargeForPlanDetailsSidebarFragmentDoc}
  ${UsageChargeForPlanDetailsSidebarFragmentDoc}
  ${EntitlementForPlanDetailsSidebarFragmentDoc}
  ${PlanForDetailsV2PlanSettingsSectionFragmentDoc}
  ${PlanForDetailsV2FixedChargesSectionFragmentDoc}
  ${PlanForDetailsV2UsageChargesSectionFragmentDoc}
  ${PlanForDetailsV2AdvancedSectionFragmentDoc}
`

const TOP_LEVEL_SECTION_IDS: PlanDetailsV2SectionId[] = [
  PlanDetailsV2SectionId.PlanSettings,
  PlanDetailsV2SectionId.FixedCharges,
  PlanDetailsV2SectionId.UsageCharges,
]

type PlanDetailsV2Props = {
  planId: string
  isInSubscriptionForm?: boolean
  subscriptionId?: string
  // Override units keyed by FixedCharge id. Populated only in subscription
  // mode by SubscriptionDetailsV2Plan, which fetches Subscription.fixedCharges
  // with fetchPolicy: 'no-cache' so plan-scope cache entries keep plan defaults.
  subscriptionFixedChargeUnitsById?: Record<string, string>
  // Refetch of that no-cache override query, so a sub-tab fixed-charge edit can
  // reliably refresh the displayed override units (see useDetailsV2ChargeMutations).
  refetchOverrides?: () => Promise<unknown>
  banner?: ReactNode
}

export const PlanDetailsV2 = ({
  planId,
  isInSubscriptionForm = false,
  subscriptionId,
  subscriptionFixedChargeUnitsById,
  refetchOverrides,
  banner,
}: PlanDetailsV2Props) => {
  const { isGated, openPremiumDialog } = useSubscriptionPremiumGate(isInSubscriptionForm)
  const { data, loading } = useGetPlanForDetailsV2Query({
    variables: { planId },
    skip: !planId,
    context: { silentError: [LagoApiError.NotFound] },
  })

  const fixedChargesRef = useRef<PlanDetailsV2FixedChargesSectionRef>(null)
  const usageChargesRef = useRef<PlanDetailsV2UsageChargesSectionRef>(null)
  const entitlementRef = useRef<EntitlementAccordionRef>(null)

  const { usageChargeMutations, fixedChargeMutations } = useDetailsV2ChargeMutations({
    plan: data?.plan,
    subscriptionId,
    refetchOverrides,
  })

  // Usage charges are virtualized: a scrolled-out charge is unmounted, so the
  // generic getElementById path would no-op. Route those ids through the section's
  // scrollToCharge (scrollToIndex + open), and keep the generic open-and-scroll for
  // the always-mounted sections / fixed charges / entitlements.
  const usageChargeIds = useMemo(
    () => new Set((data?.plan?.charges ?? []).map((charge) => charge.id)),
    [data?.plan?.charges],
  )

  // When the charge list is virtualized, the scroll path to a section below it crosses the
  // virtualizer, whose mid-scroll re-measure adjustments derail a smooth animation (lands
  // mid-list / snaps to top). Jump instantly in that case; keep smooth on small plans.
  const chargesVirtualized = shouldVirtualizeList(data?.plan?.charges?.length ?? 0)

  // BIL-160: open the target accordion first, then scroll to + focus it.
  const handleItemClick = (id: string) => {
    if (usageChargeIds.has(id)) {
      usageChargesRef.current?.scrollToCharge(id)

      return
    }

    openAccordionThenScrollTo(id, chargesVirtualized ? 'auto' : 'smooth')
  }

  const handleAddClick = (id: string) => {
    // Sub plan-override editing is premium-gated: freemium users get the upsell
    // modal instead of the create drawer.
    if (isGated) {
      openPremiumDialog()
      return
    }

    if (id === PlanDetailsV2SectionId.FixedCharges) {
      fixedChargesRef.current?.openCreate()
    }
    if (id === PlanDetailsV2SectionId.UsageCharges) {
      usageChargesRef.current?.openCreate()
    }
    if (id === PlanDetailsV2SectionId.Entitlements) {
      entitlementRef.current?.openCreate()
    }
  }

  if (loading && !data?.plan) {
    return <PlanDetailsV2Skeleton />
  }

  const plan = data?.plan

  if (!plan) {
    return null
  }

  return (
    <div className="flex gap-12">
      <PlanDetailsV2LeftSidebar
        isInSubscriptionForm={isInSubscriptionForm}
        fixedCharges={plan.fixedCharges ?? []}
        usageCharges={plan.charges ?? []}
        entitlements={plan.entitlements ?? []}
        onItemClick={handleItemClick}
        onAddClick={handleAddClick}
      />
      <div className="flex flex-1 flex-col">
        {!!banner && <div className="mt-12">{banner}</div>}
        <div
          className={tw('flex flex-col gap-12 py-12 not-last-child:pb-12 not-last-child:shadow-b')}
        >
          {TOP_LEVEL_SECTION_IDS.map((id) => {
            if (id === PlanDetailsV2SectionId.PlanSettings) {
              return (
                <PlanDetailsV2PlanSettingsSection
                  key={id}
                  plan={plan}
                  isInSubscriptionForm={isInSubscriptionForm}
                  subscriptionId={subscriptionId}
                />
              )
            }
            if (id === PlanDetailsV2SectionId.FixedCharges) {
              return (
                <PlanDetailsV2FixedChargesSection
                  key={id}
                  ref={fixedChargesRef}
                  plan={plan}
                  isInSubscriptionForm={isInSubscriptionForm}
                  fixedChargeMutations={fixedChargeMutations}
                  subscriptionFixedChargeUnitsById={subscriptionFixedChargeUnitsById}
                />
              )
            }
            if (id === PlanDetailsV2SectionId.UsageCharges) {
              return (
                <PlanDetailsV2UsageChargesSection
                  key={id}
                  ref={usageChargesRef}
                  plan={plan}
                  isInSubscriptionForm={isInSubscriptionForm}
                  chargeMutations={usageChargeMutations}
                />
              )
            }
            return (
              <section key={id} id={id} className="min-h-48 scroll-mt-12 rounded-xl bg-grey-100" />
            )
          })}
          <PlanDetailsV2AdvancedSection
            plan={plan}
            isInSubscriptionForm={isInSubscriptionForm}
            subscriptionId={subscriptionId}
            entitlementRef={entitlementRef}
          />
        </div>
      </div>
    </div>
  )
}
