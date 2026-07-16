import { z } from 'zod'

interface ThresholdRow {
  amountCents: string
  thresholdDisplayName?: string
}

export interface ProgressiveBillingFormValues {
  nonRecurringUsageThresholds: (ThresholdRow & { recurring: false })[]
  recurringUsageThreshold?: ThresholdRow & { recurring: true }
}

// Extended type for ChargeTable compatibility (requires index signature)
export type ThresholdTableData = ThresholdRow & { [key: string]: unknown }

export const progressiveBillingSchema = z.object({
  nonRecurringUsageThresholds: z
    .array(
      z.object({
        amountCents: z
          .string()
          .min(1, 'text_624ea7c29103fd010732ab7d')
          .refine((val) => Number(val) > 0, 'text_632d68358f1fedc68eed3e91'),
        thresholdDisplayName: z.string().optional(),
        recurring: z.literal(false),
      }),
    )
    .min(1)
    .superRefine((thresholds, ctx) => {
      for (let i = 1; i < thresholds.length; i++) {
        if (
          thresholds[i].amountCents.length > 0 &&
          thresholds[i - 1].amountCents.length > 0 &&
          Number(thresholds[i].amountCents) <= Number(thresholds[i - 1].amountCents)
        ) {
          ctx.addIssue({
            code: 'custom',
            message: 'text_1724252232460i4tv7384iiy',
            path: [i, 'amountCents'],
          })
        }
      }
    }),
  recurringUsageThreshold: z
    .object({
      amountCents: z
        .string()
        .min(1, 'text_624ea7c29103fd010732ab7d')
        .refine((val) => Number(val) > 0, 'text_632d68358f1fedc68eed3e91'),
      thresholdDisplayName: z.string().optional(),
      recurring: z.literal(true),
    })
    .optional(),
})

export const DEFAULT_VALUES: ProgressiveBillingFormValues = {
  nonRecurringUsageThresholds: [{ amountCents: '', recurring: false }],
  recurringUsageThreshold: undefined,
}
