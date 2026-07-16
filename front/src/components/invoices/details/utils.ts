import { ComboboxDataGrouped, ComboBoxProps } from '~/components/form'
import { ALL_FILTER_VALUES } from '~/core/constants/form'
import { composeChargeFilterDisplayName } from '~/core/formats/formatInvoiceItemsMap'
import {
  FeeForCreateFeeDrawerFragment,
  SubscriptionForCreateFeeDrawerFragment,
} from '~/generated/graphql'

// Fee type that can be used for charge selection logic
// Matches the structure needed by both invoice-level fees and regenerate mode fees
type FeeForChargeSelection = Pick<
  FeeForCreateFeeDrawerFragment,
  'charge' | 'fixedCharge' | 'chargeFilter' | 'adjustedFee'
>

function _formatChargeDataForCombobox(
  charge: NonNullable<SubscriptionForCreateFeeDrawerFragment['plan']['charges']>[number],
  groupLabel: string,
): ComboboxDataGrouped {
  const { id, invoiceDisplayName, billableMetric } = charge

  return {
    label: invoiceDisplayName || billableMetric?.name,
    description: billableMetric?.code,
    value: id,
    group: groupLabel,
  }
}

function _formatFixedChargeDataForCombobox(
  fixedCharge: NonNullable<SubscriptionForCreateFeeDrawerFragment['plan']['fixedCharges']>[number],
  groupLabel: string,
): ComboboxDataGrouped {
  const { id, invoiceDisplayName, addOn } = fixedCharge

  return {
    label: invoiceDisplayName || addOn?.name || '',
    description: addOn?.code,
    value: id,
    group: groupLabel,
  }
}

export const getChargesComboboxDataFromInvoiceSubscription = ({
  chargesGroupLabel,
  fixedChargesGroupLabel,
  subscription,
  overrideFees,
}: {
  chargesGroupLabel: string
  fixedChargesGroupLabel: string
  subscription: SubscriptionForCreateFeeDrawerFragment | undefined
  overrideFees?: FeeForChargeSelection[]
}): ComboboxDataGrouped[] => {
  if (!subscription) return []

  const feesToCheck = overrideFees

  const planUsageChargesWithoutAssociatedFees = subscription.plan.charges?.reduce<
    ComboboxDataGrouped[]
  >((acc, charge) => {
    // Check if any fee exists for this charge (without a filter)
    const chargeFeeExistsInAllFees = !feesToCheck?.some((invoiceSubFee) => {
      return invoiceSubFee.charge?.id === charge.id && !invoiceSubFee.chargeFilter
    })

    if (!charge.filters?.length) {
      if (chargeFeeExistsInAllFees)
        acc.push(_formatChargeDataForCombobox(charge, chargesGroupLabel))
      return acc
    }

    const hasAvailableFilter = charge.filters?.some((filter) => {
      // Check if a fee exists for the default filter (charge with filters but no specific filter selected)
      const defaultFilterExistsInAllFees = feesToCheck?.find((invoiceSubFee) => {
        return (
          invoiceSubFee.charge?.id === charge.id &&
          !invoiceSubFee.chargeFilter &&
          !!invoiceSubFee.charge.filters
        )
      })

      // Check if a fee exists for this specific filter
      const chargeFilterExistsInAllFees = feesToCheck?.some((invoiceSubFee) => {
        return (
          invoiceSubFee.charge?.id === charge.id && invoiceSubFee.chargeFilter?.id === filter.id
        )
      })

      return !chargeFilterExistsInAllFees || !defaultFilterExistsInAllFees
    })

    if (!hasAvailableFilter) return acc

    return [...acc, _formatChargeDataForCombobox(charge, chargesGroupLabel)]
  }, [])

  const planFixedChargesWithoutAssociatedFees = subscription.plan.fixedCharges?.reduce<
    ComboboxDataGrouped[]
  >((acc, fixedCharge) => {
    // Check if any fee exists for this fixed charge
    const fixedChargeFeeExistsInAllFees = !feesToCheck?.some((invoiceSubFee) => {
      return invoiceSubFee.fixedCharge?.id === fixedCharge.id
    })

    if (!fixedChargeFeeExistsInAllFees) return acc

    return [...acc, _formatFixedChargeDataForCombobox(fixedCharge, fixedChargesGroupLabel)]
  }, [])

  return [
    ...(planFixedChargesWithoutAssociatedFees || []),
    ...(planUsageChargesWithoutAssociatedFees || []),
  ]
}

export const getChargesFiltersComboboxDataFromInvoiceSubscription = ({
  defaultFilterOptionLabel,
  subscription,
  selectedChargeId,
  overrideFees,
}: {
  defaultFilterOptionLabel: string
  subscription: SubscriptionForCreateFeeDrawerFragment | undefined
  selectedChargeId: string | null | undefined
  overrideFees?: FeeForChargeSelection[]
}): ComboBoxProps['data'] => {
  if (!subscription || !selectedChargeId) return []

  const feesToCheck = overrideFees

  const selectedCharge = subscription.plan.charges?.find((charge) => charge.id === selectedChargeId)

  if (!selectedCharge?.filters?.length) return []

  const selectedPlanChargeFiltersWithoutAssociatedFees = selectedCharge.filters.filter((filter) => {
    // Check if any fee exists for this specific filter
    const associatedFee = feesToCheck?.some((invoiceSubFee) => {
      return (
        invoiceSubFee.charge?.id === selectedCharge.id &&
        invoiceSubFee.chargeFilter?.id === filter.id
      )
    })

    return !associatedFee
  })

  // Check if default filter is associated with a charge
  const defaultFilterExistsInAllFees = feesToCheck?.find((invoiceSubFee) => {
    return (
      invoiceSubFee.charge?.id === selectedCharge.id &&
      !invoiceSubFee.chargeFilter &&
      !!invoiceSubFee.charge.filters
    )
  })

  const comboboxData = (selectedPlanChargeFiltersWithoutAssociatedFees || []).map(
    (planChargesWithoutAssociatedFee) => {
      const { id, invoiceDisplayName } = planChargesWithoutAssociatedFee

      const paddedDisplayValues: string =
        invoiceDisplayName || composeChargeFilterDisplayName(planChargesWithoutAssociatedFee)

      return {
        label: paddedDisplayValues,
        value: id,
      }
    },
  )

  if (!defaultFilterExistsInAllFees) {
    // Add the default value at the beginning of the list
    comboboxData.unshift({
      label: defaultFilterOptionLabel,
      value: ALL_FILTER_VALUES,
    })
  }

  return comboboxData
}
