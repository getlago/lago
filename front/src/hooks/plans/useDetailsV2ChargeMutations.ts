import { FixedChargeMutations } from '~/components/plans/details-v2/PlanDetailsV2FixedChargesSection'
import { UsageChargeMutations } from '~/components/plans/details-v2/PlanDetailsV2UsageChargesSection'
import { CurrencyEnum, PlanDetailsV2Fragment } from '~/generated/graphql'
import { useChargeMutationsWithCascade } from '~/hooks/plans/useChargeMutationsWithCascade'
import { useFixedChargeMutationsWithCascade } from '~/hooks/plans/useFixedChargeMutationsWithCascade'
import { useSubscriptionChargeMutations } from '~/hooks/plans/useSubscriptionChargeMutations'
import { useSubscriptionFixedChargeMutations } from '~/hooks/plans/useSubscriptionFixedChargeMutations'

type Args = {
  plan:
    | Pick<PlanDetailsV2Fragment, 'id' | 'amountCurrency' | 'hasOverriddenPlans' | 'fixedCharges'>
    | null
    | undefined
  subscriptionId?: string
  // Refetch of the override-units query, threaded down so a sub-tab fixed-charge
  // edit reliably refreshes the displayed override units. See
  // useSubscriptionFixedChargeMutations.
  refetchOverrides?: () => Promise<unknown>
}

type Result = {
  usageChargeMutations: UsageChargeMutations
  fixedChargeMutations: FixedChargeMutations
}

export const useDetailsV2ChargeMutations = ({
  plan,
  subscriptionId,
  refetchOverrides,
}: Args): Result => {
  const currency = (plan?.amountCurrency as CurrencyEnum) ?? CurrencyEnum.Usd

  // All four hooks run unconditionally (rules of hooks). The plan-mode hooks
  // only set up mutation fns; they are never invoked when subscriptionId is set.
  const planUsage = useChargeMutationsWithCascade({
    planId: plan?.id ?? '',
    hasOverriddenPlans: plan?.hasOverriddenPlans ?? false,
    currency,
  })
  const planFixed = useFixedChargeMutationsWithCascade({
    planId: plan?.id ?? '',
    hasOverriddenPlans: plan?.hasOverriddenPlans ?? false,
  })
  const subUsage = useSubscriptionChargeMutations({
    subscriptionId: subscriptionId ?? '',
    currency,
  })
  const subFixed = useSubscriptionFixedChargeMutations({
    subscriptionId: subscriptionId ?? '',
    fixedCharges: plan?.fixedCharges,
    refetchOverrides,
  })

  return subscriptionId
    ? { usageChargeMutations: subUsage, fixedChargeMutations: subFixed }
    : { usageChargeMutations: planUsage, fixedChargeMutations: planFixed }
}
