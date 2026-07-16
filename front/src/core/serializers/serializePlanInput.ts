import {
  LocalChargeFilterInput,
  LocalPricingUnitType,
  PlanFormInput,
} from '~/components/plans/types'
import {
  ChargeFilterInput,
  ChargeModelEnum,
  CurrencyEnum,
  FixedChargeChargeModelEnum,
  FixedChargePropertiesInput,
  Properties,
} from '~/generated/graphql'

import { serializeAmount } from './serializeAmount'

const serializeScientificNotation = (value: string): string => {
  if (!value) return '0'

  return Number(value).toLocaleString('en-US', { maximumFractionDigits: 15, useGrouping: false })
}

export const serializeFilters = (
  filters: LocalChargeFilterInput[] | undefined,
  chargeModel: ChargeModelEnum,
): ChargeFilterInput[] | undefined => {
  if (!filters?.length) return []

  return filters.map(({ values, properties, invoiceDisplayName, ...filterProps }) => {
    const allValuesAsJson = values.map((value) => JSON.parse(value))
    const pricingGroupKeys = allValuesAsJson.reduce(
      (acc, cur) => {
        const [key, value] = Object.entries(cur)[0]

        if (!acc[key]) {
          acc[key] = []
        }
        acc[key].push(value as string)
        return acc
      },
      {} as Record<string, string[]>,
    )

    return {
      ...filterProps,
      invoiceDisplayName: invoiceDisplayName || null,
      properties: serializeProperties(properties as Properties, chargeModel),
      values: pricingGroupKeys,
    }
  })
}

// Transform the string we get from UI to the boolean for API
const serializeDisplayInInvoiceValue = (
  value: 'true' | 'false' | undefined,
): boolean | undefined => {
  if (value === 'true') return true
  if (value === 'false') return false
  return undefined
}

export const serializeProperties = (properties: Properties, chargeModel: ChargeModelEnum) => {
  return {
    ...properties,
    ...(![ChargeModelEnum.Custom].includes(chargeModel)
      ? {
          pricingGroupKeys: !!properties?.pricingGroupKeys?.length
            ? properties?.pricingGroupKeys
            : undefined,
          presentationGroupKeys: !!properties?.presentationGroupKeys?.length
            ? properties.presentationGroupKeys.map((key) => ({
                ...key,
                options: {
                  ...key.options,
                  // ComboBoxField stores strings; convert back to boolean for the API
                  displayInInvoice: serializeDisplayInInvoiceValue(
                    key.options?.displayInInvoice as 'true' | 'false' | undefined,
                  ),
                },
              }))
            : undefined,
        }
      : { pricingGroupKeys: undefined, presentationGroupKeys: undefined }),
    ...([ChargeModelEnum.Package, ChargeModelEnum.Standard].includes(chargeModel)
      ? { amount: !!properties?.amount ? String(properties?.amount) : undefined }
      : {}),
    ...(chargeModel === ChargeModelEnum.Graduated
      ? {
          graduatedRanges: properties?.graduatedRanges
            ? (properties?.graduatedRanges || []).map(
                ({ flatAmount, fromValue, perUnitAmount, ...range }) => ({
                  flatAmount: serializeScientificNotation(flatAmount),
                  fromValue: fromValue || 0,
                  perUnitAmount: serializeScientificNotation(perUnitAmount),
                  ...range,
                }),
              )
            : undefined,
        }
      : { graduatedRanges: undefined }),
    ...(chargeModel === ChargeModelEnum.GraduatedPercentage
      ? {
          graduatedPercentageRanges: properties?.graduatedPercentageRanges
            ? (properties?.graduatedPercentageRanges || []).map(
                ({ flatAmount, fromValue, rate, ...range }) => ({
                  flatAmount: serializeScientificNotation(flatAmount),
                  fromValue: fromValue || 0,
                  rate: serializeScientificNotation(rate),
                  ...range,
                }),
              )
            : undefined,
        }
      : { graduatedPercentageRanges: undefined }),
    ...(chargeModel === ChargeModelEnum.Volume
      ? {
          volumeRanges: properties?.volumeRanges
            ? (properties?.volumeRanges || []).map(
                ({ flatAmount, fromValue, perUnitAmount, ...range }) => ({
                  flatAmount: serializeScientificNotation(flatAmount),

                  fromValue: fromValue || 0,
                  perUnitAmount: serializeScientificNotation(perUnitAmount),
                  ...range,
                }),
              )
            : undefined,
        }
      : { volumeRanges: undefined }),
    ...(chargeModel === ChargeModelEnum.Package
      ? { freeUnits: properties?.freeUnits || 0 }
      : { packageSize: undefined, freeUnits: undefined }),
    ...(chargeModel === ChargeModelEnum.Percentage
      ? {
          amount: undefined,
          freeUnitsPerEvents: Number(properties?.freeUnitsPerEvents) || undefined,
          fixedAmount:
            Number(properties?.fixedAmount || 0) > 0 ? String(properties?.fixedAmount) : undefined,
          freeUnitsPerTotalAggregation: !!properties?.freeUnitsPerTotalAggregation
            ? String(properties?.freeUnitsPerTotalAggregation)
            : undefined,
          perTransactionMinAmount: !!properties?.perTransactionMinAmount
            ? String(properties?.perTransactionMinAmount || 0)
            : undefined,
          perTransactionMaxAmount: !!properties?.perTransactionMaxAmount
            ? String(properties?.perTransactionMaxAmount || 0)
            : undefined,
        }
      : { perTransactionMinAmount: undefined, perTransactionMaxAmount: undefined }),
    ...(chargeModel === ChargeModelEnum.Custom
      ? { customProperties: properties?.customProperties }
      : { customProperties: undefined }),
  }
}

// Fixed charges seed the full property shape (getPropertyShape) but their input
// type only supports amount / graduatedRanges / volumeRanges. Emit just the
// fields valid for the selected model so usage-only fields never leak through.
export const serializeFixedChargeProperties = (
  properties: FixedChargePropertiesInput | null | undefined,
  chargeModel: FixedChargeChargeModelEnum,
): FixedChargePropertiesInput => {
  switch (chargeModel) {
    case FixedChargeChargeModelEnum.Graduated:
      return {
        graduatedRanges: properties?.graduatedRanges?.map(
          ({ flatAmount, fromValue, perUnitAmount, ...range }) => ({
            ...range,
            flatAmount: serializeScientificNotation(flatAmount),
            fromValue: fromValue || 0,
            perUnitAmount: serializeScientificNotation(perUnitAmount),
          }),
        ),
      }
    case FixedChargeChargeModelEnum.Volume:
      return {
        volumeRanges: properties?.volumeRanges?.map(
          ({ flatAmount, fromValue, perUnitAmount, ...range }) => ({
            ...range,
            flatAmount: serializeScientificNotation(flatAmount),
            fromValue: fromValue || 0,
            perUnitAmount: serializeScientificNotation(perUnitAmount),
          }),
        ),
      }
    case FixedChargeChargeModelEnum.Standard:
    default:
      return { amount: properties?.amount ? String(properties.amount) : undefined }
  }
}

export const serializeMinimumCommitment = (
  minimumCommitment: PlanFormInput['minimumCommitment'],
  currency: CurrencyEnum,
) =>
  !!minimumCommitment && !!Object.keys(minimumCommitment).length
    ? {
        ...minimumCommitment,
        amountCents: Number(serializeAmount(minimumCommitment.amountCents, currency)),
        taxCodes: minimumCommitment.taxes?.map(({ code }) => code) || [],
        taxes: undefined,
      }
    : {}

// Always returns an array: the API only clears existing thresholds when it
// receives an explicit empty array, while an absent key means "leave untouched"
// (Plans::UpdateService gates on params.key?(:usage_thresholds)).
export const serializeUsageThresholds = (
  nonRecurringUsageThresholds: PlanFormInput['nonRecurringUsageThresholds'],
  recurringUsageThreshold: PlanFormInput['recurringUsageThreshold'],
  currency: CurrencyEnum,
) => [
  ...(nonRecurringUsageThresholds ?? []).map(
    ({ amountCents, recurring, thresholdDisplayName }) => ({
      recurring: !!recurring,
      thresholdDisplayName: thresholdDisplayName ?? null,
      amountCents: Number(serializeAmount(amountCents, currency)),
    }),
  ),
  ...(recurringUsageThreshold
    ? [
        {
          recurring: !!recurringUsageThreshold.recurring,
          thresholdDisplayName: recurringUsageThreshold.thresholdDisplayName ?? null,
          amountCents: Number(serializeAmount(recurringUsageThreshold.amountCents, currency)),
        },
      ]
    : []),
]

export const serializeEntitlements = (entitlements: PlanFormInput['entitlements']) =>
  entitlements.map(({ privileges, ...entitlement }) => ({
    ...entitlement,
    // Not needed in the backend, only FE display purpose
    featureId: undefined,
    featureName: undefined,
    privileges: privileges.map(({ ...privilege }) => ({
      ...privilege,
      // Not needed in the backend, only FE display purpose
      privilegeName: undefined,
      valueType: undefined,
      config: undefined,
      id: undefined,
    })),
  }))

export const serializePlanInput = (values: PlanFormInput) => {
  const {
    amountCents,
    entitlements,
    trialPeriod,
    charges,
    fixedCharges,
    taxes: planTaxes,
    minimumCommitment,
    nonRecurringUsageThresholds,
    recurringUsageThreshold,
    cascadeUpdates,
    ...otherValues
  } = values

  return {
    amountCents: Number(serializeAmount(amountCents, values.amountCurrency)),
    trialPeriod: Number(trialPeriod || 0),
    taxCodes: planTaxes?.map(({ code }) => code) || [],
    entitlements: serializeEntitlements(entitlements),
    fixedCharges: fixedCharges.map(({ addOn, ...fixedCharge }) => ({
      ...fixedCharge,
      addOnId: addOn.id,
      taxCodes: fixedCharge.taxes?.map(({ code }) => code) || [],
      // Cleaning display only attributes, see plans/types.ts for details
      addon: undefined,
      taxes: undefined,
      properties: serializeFixedChargeProperties(fixedCharge.properties, fixedCharge.chargeModel),
    })),
    minimumCommitment: serializeMinimumCommitment(minimumCommitment, values.amountCurrency),
    usageThresholds: serializeUsageThresholds(
      nonRecurringUsageThresholds,
      recurringUsageThreshold,
      values.amountCurrency,
    ),
    charges: charges.map(
      ({
        billableMetric,
        chargeModel,
        properties,
        minAmountCents,
        taxes: chargeTaxes,
        filters,
        appliedPricingUnit,
        payInAdvance,
        ...charge
      }) => {
        return {
          chargeModel,
          billableMetricId: billableMetric.id,
          appliedPricingUnit:
            !appliedPricingUnit || appliedPricingUnit?.type === LocalPricingUnitType.Fiat
              ? undefined
              : {
                  code: appliedPricingUnit?.code,
                  conversionRate: Number(appliedPricingUnit?.conversionRate),
                },
          minAmountCents:
            !!minAmountCents && !payInAdvance
              ? Number(serializeAmount(minAmountCents, values.amountCurrency) || 0)
              : undefined,
          payInAdvance: payInAdvance || false,
          taxCodes: chargeTaxes?.map(({ code }) => code) || [],
          filters: serializeFilters(filters, chargeModel),
          properties: properties
            ? {
                ...serializeProperties(properties as Properties, chargeModel),
              }
            : undefined,
          ...charge,
        }
      },
    ),
    ...(typeof cascadeUpdates === 'undefined' ? {} : { cascadeUpdates }),
    ...otherValues,
  }
}
