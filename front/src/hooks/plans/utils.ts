import { LocalPricingUnitType, LocalUsageChargeInput } from '~/components/plans/types'
import { transformFilterObjectToString } from '~/components/plans/utils'
import getPropertyShape from '~/core/serializers/getPropertyShape'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import {
  CurrencyEnum,
  PlanInterval,
  TaxForPlanSettingsSectionFragment,
  UsageChargeForDetailsV2Fragment,
} from '~/generated/graphql'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const formatAnyToValueForChargeFormArrays = (toValue: any, fromValue: number | string) => {
  if (toValue === null) return null

  if (Number(toValue || 0) <= Number(fromValue)) {
    return Number(fromValue) + 1
  }

  return Number(toValue || 0)
}

type PlanSettingsSourceShape = {
  name?: string | null
  code?: string | null
  description?: string | null
  interval?: PlanInterval | null
  amountCurrency?: CurrencyEnum | null
  billChargesMonthly?: boolean | null
  billFixedChargesMonthly?: boolean | null
  taxes?: TaxForPlanSettingsSectionFragment[] | null
  fixedCharges?: Array<{ id: string }> | null
  charges?: Array<{ id: string }> | null
}

export type PlanSettingsValues = {
  name: string
  code: string
  description: string
  interval: PlanInterval
  amountCurrency: CurrencyEnum
  billChargesMonthly: boolean
  billFixedChargesMonthly: boolean
  taxes: TaxForPlanSettingsSectionFragment[]
  fixedCharges: Array<{ id: string }>
  charges: Array<{ id: string }>
}

export const buildPlanSettingsValues = (plan: PlanSettingsSourceShape): PlanSettingsValues => ({
  name: plan.name ?? '',
  code: plan.code ?? '',
  description: plan.description ?? '',
  interval: plan.interval ?? PlanInterval.Monthly,
  amountCurrency: plan.amountCurrency ?? CurrencyEnum.Usd,
  billChargesMonthly: plan.billChargesMonthly ?? false,
  billFixedChargesMonthly: plan.billFixedChargesMonthly ?? false,
  taxes: plan.taxes ?? [],
  fixedCharges: (plan.fixedCharges ?? []).map((fc) => ({ id: fc.id })),
  charges: (plan.charges ?? []).map((c) => ({ id: c.id })),
})

// Hydrate a server-side Charge (UsageChargeForDetailsV2 shape) into the local
// form shape consumed by both the drawer form and serializePlanInput. Mirrors
// the deserialization v1 `usePlanForm` performs inline.
export const toLocalUsageChargeInput = (
  charge: UsageChargeForDetailsV2Fragment,
  planCurrency: CurrencyEnum,
  hasAnyPricingUnitConfigured: boolean,
): LocalUsageChargeInput => {
  const minAmountCentsNumber = Number(charge.minAmountCents)
  const hasMinAmount =
    charge.minAmountCents !== null &&
    charge.minAmountCents !== undefined &&
    !isNaN(minAmountCentsNumber) &&
    String(charge.minAmountCents) !== '0'

  return {
    id: charge.id,
    code: charge.code,
    billableMetric: charge.billableMetric,
    appliedPricingUnit:
      !hasAnyPricingUnitConfigured && !charge.appliedPricingUnit
        ? undefined
        : {
            code: charge.appliedPricingUnit?.pricingUnit?.code ?? planCurrency,
            conversionRate: String(charge.appliedPricingUnit?.conversionRate ?? ''),
            shortName: charge.appliedPricingUnit?.pricingUnit?.shortName ?? planCurrency,
            type: charge.appliedPricingUnit?.pricingUnit?.code
              ? LocalPricingUnitType.Custom
              : LocalPricingUnitType.Fiat,
          },
    chargeModel: charge.chargeModel,
    invoiceDisplayName: charge.invoiceDisplayName ?? '',
    invoiceable: charge.invoiceable ?? true,
    minAmountCents: hasMinAmount
      ? String(deserializeAmount(charge.minAmountCents ?? 0, planCurrency))
      : '',
    payInAdvance: charge.payInAdvance ?? false,
    prorated: charge.prorated ?? false,
    properties: charge.properties ? getPropertyShape(charge.properties) : undefined,
    filters: (charge.filters ?? []).map((filter) => ({
      invoiceDisplayName: filter.invoiceDisplayName ?? '',
      properties: getPropertyShape(filter.properties),
      values: Object.entries((filter.values as Record<string, string[]>) || {}).reduce<string[]>(
        (acc, [key, objectValues]) => {
          objectValues.forEach((v) => {
            acc.push(transformFilterObjectToString(key, v))
          })
          return acc
        },
        [],
      ),
    })),
    regroupPaidFees: charge.regroupPaidFees ?? null,
    taxes: charge.taxes,
  }
}
