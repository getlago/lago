import {
  ChargeUsage,
  GetCustomerProjectedUsageForPortalQuery,
  GetCustomerUsageForPortalQuery,
  ProjectedUsageForSubscriptionUsageQuery,
  UsageForSubscriptionUsageQuery,
} from '~/generated/graphql'

import { TSubscriptionUsageLifetimeGraphDataResult } from './SubscriptionUsageLifetimeGraph'

type UsageQueryResult =
  | UsageForSubscriptionUsageQuery
  | ProjectedUsageForSubscriptionUsageQuery
  | GetCustomerUsageForPortalQuery
  | GetCustomerProjectedUsageForPortalQuery

/**
 * Finds a charge usage by billable metric ID from various usage query result types
 * @param data - The usage query result data
 * @param billableMetricId - The billable metric ID to search for
 * @returns The matching ChargeUsage or undefined if not found
 */
export const findChargeUsageByBillableMetricId = (
  data: UsageQueryResult | null | undefined,
  billableMetricId: string,
): ChargeUsage | undefined => {
  if (!data) {
    return undefined
  }

  if ('customerPortalCustomerUsage' in data) {
    return data?.customerPortalCustomerUsage.chargesUsage.find(
      (usage) => usage.billableMetric.id === billableMetricId,
    ) as ChargeUsage | undefined
  }

  if ('customerUsage' in data) {
    return data?.customerUsage.chargesUsage.find(
      (usage) => usage.billableMetric.id === billableMetricId,
    ) as ChargeUsage | undefined
  }

  if ('customerProjectedUsage' in data) {
    return data?.customerProjectedUsage.chargesUsage.find(
      (usage) => usage.billableMetric.id === billableMetricId,
    ) as ChargeUsage | undefined
  }

  if ('customerPortalCustomerProjectedUsage' in data) {
    return data?.customerPortalCustomerProjectedUsage.chargesUsage.find(
      (usage) => usage.billableMetric.id === billableMetricId,
    ) as ChargeUsage | undefined
  }

  return undefined
}

export const getLifetimeGraphPercentages = (
  lifetimeUsage?: TSubscriptionUsageLifetimeGraphDataResult,
): {
  nextThresholdPercentage: number
  lastThresholdPercentage: number
} => {
  if (!lifetimeUsage) {
    return {
      nextThresholdPercentage: 0,
      lastThresholdPercentage: 0,
    }
  }

  const localTotalUsageAmountCents = Number(lifetimeUsage.totalUsageAmountCents || 0)
  const localLastThresholdAmountCents = Number(lifetimeUsage.lastThresholdAmountCents || 0)
  const localNextThresholdAmountCents = Number(lifetimeUsage.nextThresholdAmountCents || 0)
  let localLastThresholdPercentage = 0
  let localNextThresholdPercentage = 0

  if (!localNextThresholdAmountCents) {
    localLastThresholdPercentage = 100
  } else {
    localLastThresholdPercentage =
      ((localTotalUsageAmountCents - localLastThresholdAmountCents) * 100) /
      (localNextThresholdAmountCents - localLastThresholdAmountCents)
    localNextThresholdPercentage = 100 - localLastThresholdPercentage
  }

  return {
    nextThresholdPercentage: localNextThresholdPercentage,
    lastThresholdPercentage: localLastThresholdPercentage,
  }
}
