// src/core/serializers/buildPlanPreviewData.ts
import type {
  LocalFixedChargeInput,
  LocalUsageChargeInput,
  PlanFormInput,
} from '~/components/plans/types'
import { ChargeModelEnum, FixedChargeChargeModelEnum, PlanInterval } from '~/generated/graphql'

type BilledTiming = 'beginningOfPeriod' | 'endOfPeriod' | 'onTransaction'

export type PreviewCellValue =
  | { type: 'count'; value: number }
  | { type: 'displayAmount'; amount: string }
  | { type: 'percentage'; rate: string }
  | { type: 'usageBased' }
  | { type: 'variesWithUsage' }
  | { type: 'empty' }

export type PreviewDetailLabel =
  // `key` is a name in the Translation Key Map; the component resolves K.<key>.
  | { type: 'text'; key: string }
  | { type: 'tierRange'; from: number; to?: number }
  | { type: 'flatFeeForTier'; from: number; to?: number }

export type PreviewQualifier =
  | { type: 'perUnit' }
  | { type: 'flatFee' }
  | { type: 'percentOfVolume' }
  | { type: 'perPackage'; size: number }
  | { type: 'firstNUnits'; count: number }
  | { type: 'firstNTransactions'; count: number }
  | { type: 'perTransaction' }
  | { type: 'commitment' }

type PlanPreviewMainRow = {
  kind: 'main'
  rowType: 'subscriptionFee' | 'fixedCharge' | 'usageCharge' | 'minimumCommitment'
  name?: string
  description?: string
  interval: PlanInterval
  timing: BilledTiming
  units: PreviewCellValue
  price: PreviewCellValue
}

type PlanPreviewDetailRow = {
  kind: 'detail'
  label: PreviewDetailLabel
  qualifier: PreviewQualifier
  value: PreviewCellValue
}

export type PlanPreviewRow = PlanPreviewMainRow | PlanPreviewDetailRow

export type PlanPreviewData = { rows: PlanPreviewRow[] }

const num = (v: unknown): number => {
  const n = typeof v === 'number' ? v : Number.parseFloat(typeof v === 'string' ? v : '')

  return Number.isFinite(n) ? n : 0
}

// Property bags are typed `unknown`; coerce only primitives so an unexpected
// object never stringifies to '[object Object]'.
const amountStr = (v: unknown, fallback = '0'): string =>
  typeof v === 'string' || typeof v === 'number' ? String(v) : fallback

const fixedTiming = (payInAdvance: boolean): BilledTiming =>
  payInAdvance ? 'beginningOfPeriod' : 'endOfPeriod'

const usageTiming = (payInAdvance: boolean): BilledTiming =>
  payInAdvance ? 'onTransaction' : 'endOfPeriod'

// Percentage charges are always quoted on transaction, regardless of pay-in-advance.
const usageChargeTiming = (charge: LocalUsageChargeInput): BilledTiming =>
  charge.chargeModel === ChargeModelEnum.Percentage
    ? 'onTransaction'
    : usageTiming(charge.payInAdvance ?? false)

// Charge cadence: monthly override applies when the plan is non-monthly and the
// monthly-billing flag is set; otherwise the plan interval. (Assumption — verify
// against product expectations; see plan notes.)
const usageInterval = (form: PlanFormInput): PlanInterval =>
  form.billChargesMonthly && form.interval !== PlanInterval.Monthly
    ? PlanInterval.Monthly
    : form.interval

const fixedInterval = (form: PlanFormInput): PlanInterval =>
  form.billFixedChargesMonthly && form.interval !== PlanInterval.Monthly
    ? PlanInterval.Monthly
    : form.interval

const chargeName = (charge: {
  invoiceDisplayName?: string | null
  billableMetric?: { name?: string }
}): string => charge.invoiceDisplayName || charge.billableMetric?.name || ''

type Range = {
  fromValue: number
  toValue?: number | null
  perUnitAmount?: string
  flatAmount?: string
}

const tierRows = (ranges: Range[]): PlanPreviewDetailRow[] =>
  ranges.flatMap((r) => {
    const out: PlanPreviewDetailRow[] = [
      {
        kind: 'detail',
        label: {
          type: 'tierRange',
          from: num(r.fromValue),
          to: r.toValue === null || r.toValue === undefined ? undefined : num(r.toValue),
        },
        qualifier: { type: 'perUnit' },
        value: { type: 'displayAmount', amount: String(r.perUnitAmount ?? '0') },
      },
    ]

    if (num(r.flatAmount) > 0) {
      out.push({
        kind: 'detail',
        label: {
          type: 'flatFeeForTier',
          from: num(r.fromValue),
          to: r.toValue === null || r.toValue === undefined ? undefined : num(r.toValue),
        },
        qualifier: { type: 'flatFee' },
        value: { type: 'displayAmount', amount: String(r.flatAmount) },
      })
    }

    return out
  })

const standardDetailRows = (props: Record<string, unknown>): PlanPreviewDetailRow[] => [
  {
    kind: 'detail',
    label: { type: 'text', key: 'labelUsage' },
    qualifier: { type: 'perUnit' },
    value: { type: 'displayAmount', amount: amountStr(props.amount) },
  },
]

const packageDetailRows = (props: Record<string, unknown>): PlanPreviewDetailRow[] => {
  const out: PlanPreviewDetailRow[] = []

  if (num(props.freeUnits) > 0) {
    out.push({
      kind: 'detail',
      label: { type: 'text', key: 'labelFreeUnits' },
      qualifier: { type: 'firstNUnits', count: num(props.freeUnits) },
      value: { type: 'displayAmount', amount: '0' },
    })
  }
  out.push({
    kind: 'detail',
    label: { type: 'text', key: 'labelPackage' },
    qualifier: { type: 'perPackage', size: num(props.packageSize) },
    value: { type: 'displayAmount', amount: amountStr(props.amount) },
  })

  return out
}

const percentageDetailRows = (props: Record<string, unknown>): PlanPreviewDetailRow[] => {
  const out: PlanPreviewDetailRow[] = []

  if (num(props.freeUnitsPerTotalAggregation) > 0) {
    out.push({
      kind: 'detail',
      label: { type: 'text', key: 'labelFreeVolume' },
      qualifier: { type: 'firstNUnits', count: num(props.freeUnitsPerTotalAggregation) },
      value: { type: 'percentage', rate: '0' },
    })
  }
  if (num(props.freeUnitsPerEvents) > 0) {
    out.push({
      kind: 'detail',
      label: { type: 'text', key: 'labelFreeTransactions' },
      qualifier: { type: 'firstNTransactions', count: num(props.freeUnitsPerEvents) },
      value: { type: 'percentage', rate: '0' },
    })
  }
  // Always-present transaction cost
  out.push({
    kind: 'detail',
    label: { type: 'text', key: 'labelTransactionCost' },
    qualifier: { type: 'percentOfVolume' },
    value: { type: 'percentage', rate: amountStr(props.rate) },
  })
  if (num(props.fixedAmount) > 0) {
    out.push({
      kind: 'detail',
      label: { type: 'text', key: 'labelFixedFee' },
      qualifier: { type: 'perTransaction' },
      value: { type: 'displayAmount', amount: amountStr(props.fixedAmount) },
    })
  }
  if (num(props.perTransactionMinAmount) > 0) {
    out.push({
      kind: 'detail',
      label: { type: 'text', key: 'labelMinimum' },
      qualifier: { type: 'perTransaction' },
      value: { type: 'displayAmount', amount: amountStr(props.perTransactionMinAmount) },
    })
  }
  if (num(props.perTransactionMaxAmount) > 0) {
    out.push({
      kind: 'detail',
      label: { type: 'text', key: 'labelMaximum' },
      qualifier: { type: 'perTransaction' },
      value: { type: 'displayAmount', amount: amountStr(props.perTransactionMaxAmount) },
    })
  }

  return out
}

const graduatedPercentageDetailRows = (props: Record<string, unknown>): PlanPreviewDetailRow[] => {
  const ranges = (props.graduatedPercentageRanges ?? []) as Array<{
    fromValue: number
    toValue?: number | null
    rate?: string
    flatAmount?: string
  }>

  return ranges.flatMap((r) => {
    const out: PlanPreviewDetailRow[] = [
      {
        kind: 'detail',
        label: {
          type: 'tierRange',
          from: num(r.fromValue),
          to: r.toValue === null || r.toValue === undefined ? undefined : num(r.toValue),
        },
        qualifier: { type: 'percentOfVolume' },
        value: { type: 'percentage', rate: String(r.rate ?? '0') },
      },
    ]

    if (num(r.flatAmount) > 0) {
      out.push({
        kind: 'detail',
        label: {
          type: 'flatFeeForTier',
          from: num(r.fromValue),
          to: r.toValue === null || r.toValue === undefined ? undefined : num(r.toValue),
        },
        qualifier: { type: 'flatFee' },
        value: { type: 'displayAmount', amount: String(r.flatAmount) },
      })
    }

    return out
  })
}

// Dispatch per charge model. dynamic / custom → no detail rows (main usage row only).
const usageDetailRows = (charge: LocalUsageChargeInput): PlanPreviewDetailRow[] => {
  const props = (charge.properties ?? {}) as Record<string, unknown>

  switch (charge.chargeModel) {
    case ChargeModelEnum.Standard:
      return standardDetailRows(props)
    case ChargeModelEnum.Graduated:
      return tierRows((props.graduatedRanges ?? []) as Range[])
    case ChargeModelEnum.Volume:
      return tierRows((props.volumeRanges ?? []) as Range[])
    case ChargeModelEnum.Package:
      return packageDetailRows(props)
    case ChargeModelEnum.Percentage:
      return percentageDetailRows(props)
    case ChargeModelEnum.GraduatedPercentage:
      return graduatedPercentageDetailRows(props)
    default:
      return []
  }
}

export const buildPlanPreviewData = (formValues: PlanFormInput | null): PlanPreviewData => {
  if (!formValues) return { rows: [] }

  const rows: PlanPreviewRow[] = []

  // 1) Subscription fee
  if (num(formValues.amountCents) > 0) {
    rows.push({
      kind: 'main',
      rowType: 'subscriptionFee',
      name: formValues.invoiceDisplayName || undefined,
      description: undefined,
      interval: formValues.interval,
      timing: fixedTiming(formValues.payInAdvance),
      units: { type: 'count', value: 1 },
      price: { type: 'displayAmount', amount: String(formValues.amountCents) },
    })
  }

  // 2) Fixed charges
  for (const fc of formValues.fixedCharges ?? []) {
    const typedFc = fc as LocalFixedChargeInput
    const fcProps = (typedFc.properties ?? {}) as Record<string, unknown>
    const fcName = typedFc.invoiceDisplayName || typedFc.addOn?.name || undefined
    const fcInterval = fixedInterval(formValues)
    const fcTiming = fixedTiming(typedFc.payInAdvance ?? false)
    const fcUnits: PreviewCellValue = { type: 'count', value: num(typedFc.units) }

    if (typedFc.chargeModel === FixedChargeChargeModelEnum.Graduated) {
      rows.push(
        {
          kind: 'main',
          rowType: 'fixedCharge',
          name: fcName,
          description: undefined,
          interval: fcInterval,
          timing: fcTiming,
          units: fcUnits,
          price: { type: 'empty' },
        },
        ...tierRows((fcProps.graduatedRanges ?? []) as Range[]),
      )
    } else if (typedFc.chargeModel === FixedChargeChargeModelEnum.Volume) {
      rows.push(
        {
          kind: 'main',
          rowType: 'fixedCharge',
          name: fcName,
          description: undefined,
          interval: fcInterval,
          timing: fcTiming,
          units: fcUnits,
          price: { type: 'empty' },
        },
        ...tierRows((fcProps.volumeRanges ?? []) as Range[]),
      )
    } else {
      // Standard (default)
      rows.push({
        kind: 'main',
        rowType: 'fixedCharge',
        name: fcName,
        description: undefined,
        interval: fcInterval,
        timing: fcTiming,
        units: fcUnits,
        price: { type: 'displayAmount', amount: amountStr(fcProps.amount) },
      })
    }
  }

  // 3) Usage charges (each is a main row + model-specific detail rows)
  for (const charge of formValues.charges ?? []) {
    const typedCharge = charge as LocalUsageChargeInput

    rows.push(
      {
        kind: 'main',
        rowType: 'usageCharge',
        name: chargeName(typedCharge) || undefined,
        description: undefined,
        interval: usageInterval(formValues),
        timing: usageChargeTiming(typedCharge),
        units: { type: 'usageBased' },
        price: { type: 'variesWithUsage' },
      },
      ...usageDetailRows(typedCharge),
    )
    const minAmount = typedCharge.minAmountCents

    if (num(minAmount) > 0) {
      rows.push({
        kind: 'detail',
        label: { type: 'text', key: 'labelMinimumSpending' },
        qualifier: { type: 'commitment' },
        value: { type: 'displayAmount', amount: String(minAmount) },
      })
    }
  }

  // 4) Plan minimum commitment (own row)
  if (formValues.minimumCommitment) {
    rows.push({
      kind: 'main',
      rowType: 'minimumCommitment',
      name: formValues.minimumCommitment.invoiceDisplayName || undefined,
      description: undefined,
      interval: formValues.interval,
      timing: fixedTiming(formValues.payInAdvance),
      units: { type: 'count', value: 1 },
      price: {
        type: 'displayAmount',
        amount: String(formValues.minimumCommitment.amountCents ?? '0'),
      },
    })
  }

  return { rows }
}
