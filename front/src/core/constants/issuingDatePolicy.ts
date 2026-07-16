import {
  BillingEntitySubscriptionInvoiceIssuingDateAdjustmentEnum,
  BillingEntitySubscriptionInvoiceIssuingDateAnchorEnum,
  CustomerSubscriptionInvoiceIssuingDateAdjustmentEnum,
  CustomerSubscriptionInvoiceIssuingDateAnchorEnum,
} from '~/generated/graphql'

export const ALL_ADJUSTMENT_VALUES = {
  ...BillingEntitySubscriptionInvoiceIssuingDateAdjustmentEnum,
  ...CustomerSubscriptionInvoiceIssuingDateAdjustmentEnum,
} as const

export const ALL_ANCHOR_VALUES = {
  ...BillingEntitySubscriptionInvoiceIssuingDateAnchorEnum,
  ...CustomerSubscriptionInvoiceIssuingDateAnchorEnum,
} as const

export const INVOICE_ISSUING_DATE_ANCHOR_SETTING_KEYS: Record<
  (typeof ALL_ANCHOR_VALUES)[keyof typeof ALL_ANCHOR_VALUES],
  string
> = {
  [ALL_ANCHOR_VALUES.CurrentPeriodEnd]: 'text_1763407530094n4hrbk01j2h',
  [ALL_ANCHOR_VALUES.NextPeriodStart]: 'text_1763407733969w6qdmai4f88',
}

export const INVOICE_ISSUING_DATE_ADJUSTMENT_SETTING_KEYS: Record<
  (typeof ALL_ADJUSTMENT_VALUES)[keyof typeof ALL_ADJUSTMENT_VALUES],
  string
> = {
  [ALL_ADJUSTMENT_VALUES.AlignWithFinalizationDate]: 'text_1763407733969ti85rl167eb',
  [ALL_ADJUSTMENT_VALUES.KeepAnchor]: 'text_1763407733969918wvv4xkxf',
}
