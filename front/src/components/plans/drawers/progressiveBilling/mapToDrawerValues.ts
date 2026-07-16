import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum } from '~/generated/graphql'

import { ProgressiveBillingFormValues } from './constants'

type PlanUsageThreshold = {
  amountCents: string | number
  recurring: boolean
  thresholdDisplayName?: string | null
}

type FormThreshold = {
  amountCents: string | number
  thresholdDisplayName?: string | null
}

export const mapPlanThresholdsToDrawerValues = (
  usageThresholds: ReadonlyArray<PlanUsageThreshold> | null | undefined,
  currency: CurrencyEnum,
): ProgressiveBillingFormValues => {
  const list = usageThresholds ?? []
  const nonRecurringUsageThresholds = list
    .filter((threshold) => !threshold.recurring)
    .map((threshold) => ({
      amountCents: String(deserializeAmount(threshold.amountCents, currency)),
      thresholdDisplayName: threshold.thresholdDisplayName ?? undefined,
      recurring: false as const,
    }))
  const recurring = list.find((threshold) => threshold.recurring)

  return {
    nonRecurringUsageThresholds,
    recurringUsageThreshold: recurring
      ? {
          amountCents: String(deserializeAmount(recurring.amountCents, currency)),
          thresholdDisplayName: recurring.thresholdDisplayName ?? undefined,
          recurring: true as const,
        }
      : undefined,
  }
}

export const mapFormThresholdsToDrawerValues = (
  nonRecurringUsageThresholds: ReadonlyArray<FormThreshold> | null | undefined,
  recurringUsageThreshold: FormThreshold | null | undefined,
): ProgressiveBillingFormValues => ({
  nonRecurringUsageThresholds: (nonRecurringUsageThresholds ?? []).map((threshold) => ({
    amountCents: String(threshold.amountCents),
    thresholdDisplayName: threshold.thresholdDisplayName ?? undefined,
    recurring: false as const,
  })),
  recurringUsageThreshold: recurringUsageThreshold
    ? {
        amountCents: String(recurringUsageThreshold.amountCents),
        thresholdDisplayName: recurringUsageThreshold.thresholdDisplayName ?? undefined,
        recurring: true as const,
      }
    : undefined,
})
