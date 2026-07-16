import type { EntityData } from '~/components/designSystem/RichTextEditor/common/RichTextEditorContext'
import type {
  LocalFixedChargeInput,
  LocalUsageChargeInput,
  PlanFormInput,
} from '~/components/plans/types'
import { CommitmentTypeEnum } from '~/generated/graphql'

import { buildPlanPreviewData } from './buildPlanPreviewData'

// Re-export so consumers can import PlanFormInput from this serializer module.
export type { PlanFormInput }

// --- Plan billing item types (snake_case, matches backend contract) ---
interface PlanChargeOverride {
  billable_metric_code: string
  charge_model: string
  properties: Record<string, unknown>
}

interface PlanMinimumCommitmentOverride {
  amount_cents: number
  invoice_display_name?: string
}

interface PlanUsageThresholdOverride {
  amount_cents: number
  recurring: boolean
  threshold_display_name?: string
}

export interface PlanOverrides {
  amount_cents?: number
  invoice_display_name?: string
  minimum_commitment?: PlanMinimumCommitmentOverride
  charges?: PlanChargeOverride[]
  usage_thresholds?: PlanUsageThresholdOverride[]
}

// --- Serialized plan form types (stored in PlanPayload for form reconstruction) ---

interface SerializedTax {
  id: string
  code: string
  name: string
  rate: number
}

interface SerializedBillableMetric {
  id: string
  code: string
  name: string
  aggregation_type: string
  recurring: boolean
  filters: Array<{ id: string; key: string; values: string[] }>
}

interface SerializedChargeFilter {
  invoice_display_name: string | null
  properties: Record<string, unknown>
  values: string[]
}

interface SerializedAppliedPricingUnit {
  code: string
  short_name: string
  type: string
  conversion_rate: string
}

interface SerializedCharge {
  id?: string
  billable_metric: SerializedBillableMetric
  charge_model: string
  properties: Record<string, unknown>
  invoice_display_name: string
  min_amount_cents: string | undefined
  pay_in_advance: boolean
  prorated: boolean
  regroup_paid_fees: string | null
  invoiceable: boolean
  tax_codes: string[]
  taxes: SerializedTax[]
  filters: SerializedChargeFilter[]
  applied_pricing_unit: SerializedAppliedPricingUnit | null
}

interface SerializedAddOn {
  id: string
  name: string
  code: string
}

interface SerializedFixedCharge {
  id?: string
  add_on: SerializedAddOn
  charge_model: string
  units: string
  apply_units_immediately: boolean
  invoice_display_name: string | null
  pay_in_advance: boolean
  prorated: boolean
  properties: Record<string, unknown>
  tax_codes: string[]
  taxes: SerializedTax[]
}

interface SerializedMinimumCommitment {
  id?: string
  amount_cents: string
  invoice_display_name: string | null
  commitment_type: string
  tax_codes: string[]
  taxes: SerializedTax[]
}

interface SerializedUsageThreshold {
  id?: string
  amount_cents: number | string
  threshold_display_name: string | null
  recurring: boolean
}

interface PlanPayload {
  position: number
  code: string
  name: string
  description: string
  subscription_external_id: string | null
  subscription_name: string | null
  billing_time: 'anniversary' | 'calendar'
  start_date: string | null
  end_date: string | null
  payment_method_id: string | null
  invoice_custom_footer: string | null

  // --- Plan configuration (optional for backward compat with legacy payloads) ---
  interval?: string
  amount_cents?: string
  amount_currency?: string
  pay_in_advance?: boolean
  bill_charges_monthly?: boolean | null
  bill_fixed_charges_monthly?: boolean | null
  trial_period?: number
  invoice_display_name?: string | null
  tax_codes?: string[]
  taxes?: SerializedTax[]

  // --- Charges (optional for backward compat) ---
  charges?: SerializedCharge[]
  fixed_charges?: SerializedFixedCharge[]

  // --- Commitments & thresholds (optional for backward compat) ---
  minimum_commitment?: SerializedMinimumCommitment | null
  non_recurring_usage_thresholds?: SerializedUsageThreshold[]
  recurring_usage_threshold?: SerializedUsageThreshold | null
}

export interface BillingItemPlan {
  type: 'plan'
  id: string
  payload: PlanPayload
  overrides: PlanOverrides
}

// --- Frontend state types (camelCase) ---

export interface SubscriptionSettings {
  externalId: string
  subscriptionName: string
  billingTime: 'anniversary' | 'calendar'
  startDate: string
  endDate: string
}

export interface InvoicingSettings {
  paymentMethodId: string
  invoiceCustomFooter: string
}

export const DEFAULT_SUBSCRIPTION_SETTINGS: SubscriptionSettings = {
  externalId: '',
  subscriptionName: '',
  billingTime: 'anniversary',
  startDate: '',
  endDate: '',
}

export const DEFAULT_INVOICING_SETTINGS: InvoicingSettings = {
  paymentMethodId: '',
  invoiceCustomFooter: '',
}

// --- Serialization state (passed to toPlanBillingItems) ---

export interface SubscriptionPricingState {
  planId: string
  planCode: string
  planName: string
  planDescription: string
  subscriptionSettings: SubscriptionSettings
  invoicingSettings: InvoicingSettings
  // Optional: overrides are derived from form state by `toPlanBillingItems`.
  // Kept as a fallback for callers that serialize without form values.
  overrides?: PlanOverrides
}

// --- Serializer / Deserializer ---

const normalizeOptional = (value: string): string | null => (value === '' ? null : value)

const serializeTaxes = (
  taxes: Array<{ id: string; code: string; name: string; rate: number }> | null | undefined,
): SerializedTax[] => {
  if (!taxes) return []
  return taxes.map((t) => ({ id: t.id, code: t.code, name: t.name, rate: t.rate }))
}

const serializeCharge = (charge: LocalUsageChargeInput): SerializedCharge => {
  const bm = charge.billableMetric

  return {
    id: charge.id,
    billable_metric: {
      id: bm.id,
      code: bm.code,
      name: bm.name,
      aggregation_type: bm.aggregationType,
      recurring: bm.recurring,
      filters: (bm.filters ?? []).map((f) => ({ id: f.id, key: f.key, values: [...f.values] })),
    },
    charge_model: charge.chargeModel,
    properties: charge.properties ?? {},
    invoice_display_name: charge.invoiceDisplayName ?? '',
    min_amount_cents: charge.minAmountCents === null ? undefined : String(charge.minAmountCents),
    pay_in_advance: charge.payInAdvance ?? false,
    prorated: charge.prorated ?? false,
    regroup_paid_fees: (charge.regroupPaidFees as string) ?? null,
    invoiceable: charge.invoiceable ?? true,
    tax_codes: charge.taxCodes ?? [],
    taxes: serializeTaxes(charge.taxes),
    filters: (charge.filters ?? []).map((f) => ({
      invoice_display_name: (f.invoiceDisplayName as string | null) ?? null,
      properties: f.properties ?? {},
      values: f.values ?? [],
    })),
    applied_pricing_unit: charge.appliedPricingUnit
      ? {
          code: charge.appliedPricingUnit.code,
          short_name: charge.appliedPricingUnit.shortName,
          type: String(charge.appliedPricingUnit.type),
          conversion_rate: charge.appliedPricingUnit.conversionRate ?? '',
        }
      : null,
  }
}

const serializeFixedCharge = (charge: LocalFixedChargeInput): SerializedFixedCharge => {
  return {
    id: charge.id,
    add_on: {
      id: charge.addOn.id,
      name: charge.addOn.name,
      code: charge.addOn.code,
    },
    charge_model: charge.chargeModel,
    units: (charge.units as string) ?? '',
    apply_units_immediately: charge.applyUnitsImmediately ?? false,
    invoice_display_name: (charge.invoiceDisplayName as string | null) ?? null,
    pay_in_advance: charge.payInAdvance ?? false,
    prorated: charge.prorated ?? false,
    properties: charge.properties ?? {},
    tax_codes: charge.taxCodes ?? [],
    taxes: serializeTaxes(charge.taxes),
  }
}

/**
 * Builds the snake_case `overrides` payload from the plan form state.
 *
 * This is the single source of truth for the form → override mapping: it is
 * derived from the same `PlanFormInput` that feeds the plan `payload`, so the
 * two can't silently drift when a charge field is added.
 */
export const buildPlanOverrides = (formValues: PlanFormInput): PlanOverrides => {
  const overrides: PlanOverrides = {}

  // Subscription fee
  overrides.amount_cents = Number(formValues.amountCents) || undefined
  if (formValues.invoiceDisplayName) {
    overrides.invoice_display_name = formValues.invoiceDisplayName || undefined
  }

  // Fixed charges
  if (formValues.fixedCharges?.length) {
    overrides.charges = [
      ...formValues.fixedCharges.map((c) => ({
        billable_metric_code: c.addOn?.code ?? '',
        charge_model: c.chargeModel,
        properties: c.properties ?? {},
      })),
    ]
  }

  // Usage charges
  if (formValues.charges?.length) {
    overrides.charges = [
      ...(overrides.charges ?? []),
      ...formValues.charges.map((c) => ({
        billable_metric_code: c.billableMetric?.code ?? '',
        charge_model: c.chargeModel,
        properties: c.properties ?? {},
      })),
    ]
  }

  // Minimum commitment
  const mcAmount = formValues.minimumCommitment?.amountCents

  if (mcAmount && !Number.isNaN(Number(mcAmount)) && Number(mcAmount) > 0) {
    overrides.minimum_commitment = {
      amount_cents: Number(mcAmount),
      invoice_display_name: formValues.minimumCommitment?.invoiceDisplayName || undefined,
    }
  }

  // Progressive billing (usage thresholds)
  const thresholds = [
    ...(formValues.nonRecurringUsageThresholds ?? []).map((t) => ({
      amount_cents: Number(t.amountCents),
      recurring: false as const,
      threshold_display_name: t.thresholdDisplayName ?? undefined,
    })),
    ...(formValues.recurringUsageThreshold
      ? [
          {
            amount_cents: Number(formValues.recurringUsageThreshold.amountCents),
            recurring: true as const,
            threshold_display_name:
              formValues.recurringUsageThreshold.thresholdDisplayName ?? undefined,
          },
        ]
      : []),
  ]

  if (thresholds.length) {
    overrides.usage_thresholds = thresholds
  }

  return overrides
}

export const toPlanBillingItems = (
  state: SubscriptionPricingState,
  formValues?: PlanFormInput,
): { plans: BillingItemPlan[] } => {
  const { planId, planCode, planName, planDescription, subscriptionSettings, invoicingSettings } =
    state

  // Derive overrides from the form values (single source of truth). Fall back to
  // any pre-built overrides on the state for callers that serialize without form values.
  const overrides = formValues ? buildPlanOverrides(formValues) : (state.overrides ?? {})

  const payload: PlanPayload = {
    position: 1,
    code: planCode,
    name: planName,
    description: planDescription,
    subscription_external_id: normalizeOptional(subscriptionSettings.externalId),
    subscription_name: normalizeOptional(subscriptionSettings.subscriptionName),
    billing_time: subscriptionSettings.billingTime,
    start_date: normalizeOptional(subscriptionSettings.startDate),
    end_date: normalizeOptional(subscriptionSettings.endDate),
    payment_method_id: normalizeOptional(invoicingSettings.paymentMethodId),
    invoice_custom_footer: normalizeOptional(invoicingSettings.invoiceCustomFooter),
  }

  if (formValues) {
    payload.interval = formValues.interval
    payload.amount_cents = String(formValues.amountCents ?? '')
    payload.amount_currency = formValues.amountCurrency
    payload.pay_in_advance = formValues.payInAdvance ?? false
    payload.bill_charges_monthly = formValues.billChargesMonthly ?? null
    payload.bill_fixed_charges_monthly = formValues.billFixedChargesMonthly ?? null
    payload.trial_period = formValues.trialPeriod ?? 0
    payload.invoice_display_name = formValues.invoiceDisplayName ?? null
    payload.tax_codes = formValues.taxCodes ?? []
    payload.taxes = serializeTaxes(formValues.taxes)
    payload.charges = (formValues.charges ?? []).map(serializeCharge)
    payload.fixed_charges = (formValues.fixedCharges ?? []).map(serializeFixedCharge)
    payload.minimum_commitment = formValues.minimumCommitment
      ? {
          id: formValues.minimumCommitment.id ?? undefined,
          amount_cents: String(formValues.minimumCommitment.amountCents ?? ''),
          invoice_display_name:
            (formValues.minimumCommitment.invoiceDisplayName as string | null) ?? null,
          commitment_type: String(
            formValues.minimumCommitment.commitmentType ?? 'minimum_commitment',
          ),
          tax_codes: formValues.minimumCommitment.taxCodes ?? [],
          taxes: serializeTaxes(formValues.minimumCommitment.taxes),
        }
      : null
    payload.non_recurring_usage_thresholds = (formValues.nonRecurringUsageThresholds ?? []).map(
      (t) => ({
        id: undefined,
        amount_cents: t.amountCents as number | string,
        threshold_display_name: (t.thresholdDisplayName as string | null) ?? null,
        recurring: t.recurring ?? false,
      }),
    )
    payload.recurring_usage_threshold = formValues.recurringUsageThreshold
      ? {
          id: undefined,
          amount_cents: formValues.recurringUsageThreshold.amountCents as number | string,
          threshold_display_name:
            (formValues.recurringUsageThreshold.thresholdDisplayName as string | null) ?? null,
          recurring: formValues.recurringUsageThreshold.recurring ?? true,
        }
      : null
  }

  return { plans: [{ type: 'plan', id: planId, payload, overrides }] }
}

interface FromPlanBillingItemsResult {
  planId: string
  planCode: string
  planName: string
  planDescription: string
  subscriptionSettings: SubscriptionSettings
  invoicingSettings: InvoicingSettings
  overrides: PlanOverrides
  entityData: Record<string, EntityData>
  formValues: PlanFormInput | null
}

const denormalizeOptional = (value: string | null): string => value ?? ''

const deserializeTaxes = (
  taxes: SerializedTax[],
): Array<{ id: string; code: string; name: string; rate: number }> => {
  return taxes.map((t) => ({ id: t.id, code: t.code, name: t.name, rate: t.rate }))
}

const deserializeCharge = (charge: SerializedCharge): LocalUsageChargeInput => {
  const bm = charge.billable_metric

  return {
    id: charge.id,
    billableMetric: {
      id: bm.id,
      code: bm.code,
      name: bm.name,
      aggregationType: bm.aggregation_type,
      recurring: bm.recurring,
      filters: bm.filters.map((f) => ({ id: f.id, key: f.key, values: f.values })),
    } as LocalUsageChargeInput['billableMetric'],
    chargeModel: charge.charge_model as LocalUsageChargeInput['chargeModel'],
    properties: charge.properties,
    invoiceDisplayName: charge.invoice_display_name ?? undefined,
    minAmountCents: charge.min_amount_cents as LocalUsageChargeInput['minAmountCents'],
    payInAdvance: charge.pay_in_advance,
    prorated: charge.prorated,
    regroupPaidFees: charge.regroup_paid_fees as LocalUsageChargeInput['regroupPaidFees'],
    invoiceable: charge.invoiceable,
    taxCodes: charge.tax_codes,
    taxes: deserializeTaxes(charge.taxes),
    filters: charge.filters.map((f) => ({
      invoiceDisplayName: f.invoice_display_name ?? undefined,
      properties: f.properties,
      values: f.values,
    })) as LocalUsageChargeInput['filters'],
    appliedPricingUnit: charge.applied_pricing_unit
      ? ({
          code: charge.applied_pricing_unit.code,
          shortName: charge.applied_pricing_unit.short_name,
          type: charge.applied_pricing_unit.type,
          conversionRate: charge.applied_pricing_unit.conversion_rate,
        } as LocalUsageChargeInput['appliedPricingUnit'])
      : undefined,
  }
}

const deserializeFixedCharge = (charge: SerializedFixedCharge): LocalFixedChargeInput => {
  return {
    id: charge.id,
    addOn: {
      id: charge.add_on.id,
      name: charge.add_on.name,
      code: charge.add_on.code,
    },
    chargeModel: charge.charge_model as LocalFixedChargeInput['chargeModel'],
    units: charge.units,
    applyUnitsImmediately: charge.apply_units_immediately,
    invoiceDisplayName: charge.invoice_display_name ?? undefined,
    payInAdvance: charge.pay_in_advance,
    prorated: charge.prorated,
    properties: charge.properties,
    taxCodes: charge.tax_codes,
    taxes: deserializeTaxes(charge.taxes),
  }
}

export const fromPlanBillingItems = (plans: BillingItemPlan[]): FromPlanBillingItemsResult => {
  const plan = plans[0]
  const { payload, overrides, id } = plan

  const subscriptionSettings: SubscriptionSettings = {
    externalId: denormalizeOptional(payload.subscription_external_id),
    subscriptionName: denormalizeOptional(payload.subscription_name),
    billingTime: payload.billing_time,
    startDate: denormalizeOptional(payload.start_date),
    endDate: denormalizeOptional(payload.end_date),
  }

  const invoicingSettings: InvoicingSettings = {
    paymentMethodId: denormalizeOptional(payload.payment_method_id),
    invoiceCustomFooter: denormalizeOptional(payload.invoice_custom_footer),
  }

  // Backward-compat: legacy payloads don't have interval/charges
  const hasFullPlanData =
    'interval' in payload &&
    payload.interval !== null &&
    'charges' in payload &&
    payload.charges !== null

  let formValues: PlanFormInput | null = null

  if (hasFullPlanData) {
    formValues = {
      interval: payload.interval as PlanFormInput['interval'],
      amountCents: payload.amount_cents as PlanFormInput['amountCents'],
      amountCurrency: payload.amount_currency as PlanFormInput['amountCurrency'],
      payInAdvance: payload.pay_in_advance ?? false,
      billChargesMonthly: payload.bill_charges_monthly ?? undefined,
      billFixedChargesMonthly: payload.bill_fixed_charges_monthly ?? undefined,
      trialPeriod: payload.trial_period,
      invoiceDisplayName: payload.invoice_display_name ?? undefined,
      taxCodes: payload.tax_codes ?? [],
      taxes: deserializeTaxes(payload.taxes ?? []),
      charges: (payload.charges ?? []).map(deserializeCharge),
      fixedCharges: (payload.fixed_charges ?? []).map(deserializeFixedCharge),
      minimumCommitment: payload.minimum_commitment
        ? {
            id: payload.minimum_commitment.id ?? undefined,
            amountCents: payload.minimum_commitment.amount_cents,
            invoiceDisplayName: payload.minimum_commitment.invoice_display_name ?? undefined,
            commitmentType: payload.minimum_commitment.commitment_type as CommitmentTypeEnum,
            taxCodes: payload.minimum_commitment.tax_codes ?? [],
            taxes: deserializeTaxes(payload.minimum_commitment.taxes ?? []),
          }
        : undefined,
      nonRecurringUsageThresholds: (payload.non_recurring_usage_thresholds ?? []).map((t) => ({
        amountCents: t.amount_cents,
        thresholdDisplayName: t.threshold_display_name ?? undefined,
        recurring: t.recurring,
      })) as PlanFormInput['nonRecurringUsageThresholds'],
      recurringUsageThreshold: payload.recurring_usage_threshold
        ? {
            amountCents: payload.recurring_usage_threshold.amount_cents,
            thresholdDisplayName:
              payload.recurring_usage_threshold.threshold_display_name ?? undefined,
            recurring: payload.recurring_usage_threshold.recurring,
          }
        : undefined,
      entitlements: [],
      name: payload.name,
      code: payload.code,
      description: payload.description,
    }
  }

  const entityData: Record<string, EntityData> = {
    [id]: {
      entityId: id,
      entityType: 'plan',
      name: payload.name,
      code: payload.code,
      plan: buildPlanPreviewData(formValues),
    },
  }

  return {
    planId: id,
    planCode: payload.code,
    planName: payload.name,
    planDescription: payload.description,
    subscriptionSettings,
    invoicingSettings,
    overrides,
    entityData,
    formValues,
  }
}
