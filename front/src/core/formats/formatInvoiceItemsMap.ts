import { gql } from '@apollo/client'
import { DateTime } from 'luxon'

import { ALL_FILTER_VALUES } from '~/core/constants/form'
import {
  FeeForDeleteAdjustmentFeeDialogFragmentDoc,
  FeeForViewFeeDetailsDrawerFragmentDoc,
  FeeTypesEnum,
  InvoiceForFormatInvoiceItemMapFragment,
} from '~/generated/graphql'

gql`
  fragment InvoiceForFormatInvoiceItemMap on Invoice {
    id
    status
    invoiceSubscriptions {
      subscription {
        id
      }
      invoice {
        id
      }
      acceptNewChargeFees
    }
    fees {
      id
      amountCents
      currency
      preciseUnitAmount
      adjustedFee
      charge {
        id
        payInAdvance
        minAmountCents
        chargeModel
        prorated
        billableMetric {
          id
          name
          recurring
        }
      }
      chargeFilter {
        invoiceDisplayName
        values
      }
      feeType
      groupedBy
      itemName
      invoiceDisplayName
      invoiceName
      properties {
        fromDatetime
        toDatetime
      }
      pricingUnitUsage {
        amountCents
        conversionRate
        shortName
        preciseUnitAmount
      }
      subscription {
        id
      }
      trueUpParentFee {
        id
      }
      units
      fixedCharge {
        id
        chargeModel
        prorated
      }

      ...FeeForDeleteAdjustmentFeeDialog
      ...FeeForViewFeeDetailsDrawer
    }
  }

  ${FeeForDeleteAdjustmentFeeDialogFragmentDoc}
  ${FeeForViewFeeDetailsDrawerFragmentDoc}
`
// Extract the Fee type from the fragment to ensure type safety
// This ensures TypeScript will error if we try to access fields not included in the fragment
type FeeFromFragment = NonNullable<
  NonNullable<InvoiceForFormatInvoiceItemMapFragment['fees']>[number]
>

// AssociatedSubscription type should come from a fragment that includes subscriptions
// (like InvoiceForInvoiceDetailsTableFragment) rather than this fragment
export type AssociatedSubscription = {
  id: string
  name?: string | null
  currentBillingPeriodStartedAt?: string | null
  currentBillingPeriodEndingAt?: string | null
  plan: {
    id: string
    name: string
    interval: string
    invoiceDisplayName?: string | null
  }
}

// InvoiceSubscription type for the join table between Invoice and Subscription
export type AssociatedInvoiceSubscription = {
  subscription: {
    id: string
  }
  invoice: {
    id: string
  }
  acceptNewChargeFees: boolean
}

// Metadata added to fees during processing
export type FeeMetadata = {
  displayName: string
  isCommitmentFee?: boolean
  isFilterChildFee?: boolean
  isFixedCharge?: boolean
  isNormalFee?: boolean
  isSubscriptionFee?: boolean
  isTrueUpFee?: boolean
}

// Generic type for fees with metadata - works with any fee fragment
export type TExtendedFee<T> = T & {
  metadata: FeeMetadata
}

// Specific type for fees from this fragment
export type TExtendedRemainingFee = TExtendedFee<FeeFromFragment>

// Generic boundary data type that works with any fee type
type TBoundaryDataForDisplay<TFee = TExtendedRemainingFee> = {
  fromDatetime: string
  toDatetime: string
  fees: TFee[]
}

type TBoundariesForDisplay<TFee = TExtendedRemainingFee> = {
  [boundaryKey: string]: TBoundaryDataForDisplay<TFee>
}

// Subscription data grouped by subscription ID with boundaries inside
export type TSubscriptionDataForDisplay<TFee = TExtendedRemainingFee> = {
  [subscriptionId: string]: {
    acceptNewChargeFees: boolean
    boundaries: TBoundariesForDisplay<TFee>
    subscriptionDisplayName: string
  }
}

export const composeChargeFilterDisplayName = (
  chargeFilter?: {
    id?: string | null
    invoiceDisplayName?: string | null
    values: Record<string, string[]>
  } | null,
): string => {
  if (!chargeFilter) return ''
  if (chargeFilter.invoiceDisplayName) return chargeFilter.invoiceDisplayName

  return Object.entries(chargeFilter.values)
    .map((value) => {
      const [k, v] = value as [string, string[]]

      if (v.includes(ALL_FILTER_VALUES)) {
        return `${k}`
      }

      return v.join(' • ')
    })
    .join(' • ')
}

export const composeGroupedByDisplayName = (
  groupedBy?: Record<string, string | null> | null,
): string => {
  if (!groupedBy || !Object.keys(groupedBy).length) return ''

  return Object.values(groupedBy || {})
    .filter((v) => !!v)
    .map((g) => `${g}`)
    .join(' • ')
}

export const composeMultipleValuesWithSepator = (
  values?: Array<string | undefined | null>,
): string => {
  if (!values?.length) return ''

  return values.filter((v) => !!v).join(' • ')
}

/**
 * Creates a unique boundary key from fromDatetime and toDatetime
 * Normalizes dates to YYYY-MM-DD format to ensure fees with the same date
 * but different times are grouped together
 *
 * @param fromDatetime - Start date of the boundary (ISO string)
 * @param toDatetime - End date of the boundary (ISO string)
 * @returns A unique key for the boundary based on dates only (without time)
 */
export const createBoundaryKey = (
  fromDatetime: string | null | undefined,
  toDatetime: string | null | undefined,
): string => {
  const fromDate = !!fromDatetime
    ? DateTime.fromISO(fromDatetime, { zone: 'utc' }).toISODate() || fromDatetime
    : 'no-from'
  const toDate = !!toDatetime
    ? DateTime.fromISO(toDatetime, { zone: 'utc' }).toISODate() || toDatetime
    : 'no-to'

  return `${fromDate}_${toDate}`
}

/**
 * Generates display name for subscription fees
 * Works with any fee that has invoiceDisplayName field
 */
export const getSubscriptionFeeDisplayName = <
  TFee extends Pick<FeeFromFragment, 'invoiceDisplayName'>,
  TSub extends Pick<AssociatedSubscription, 'plan'>,
>(
  fee: TFee,
  subscription: TSub,
): string => {
  if (!!fee.invoiceDisplayName) {
    return fee.invoiceDisplayName
  }

  const plan = subscription?.plan
  const capitalizedPlanInterval = `${plan?.interval
    ?.charAt(0)
    ?.toUpperCase()}${plan?.interval?.slice(1)}`

  return `${capitalizedPlanInterval} subscription fee - ${plan?.name}`
}

/**
 * Minimum fields required from a fee to generate its display name
 */
type FeeForDisplayName = Pick<
  FeeFromFragment,
  | 'feeType'
  | 'invoiceDisplayName'
  | 'itemName'
  | 'invoiceName'
  | 'groupedBy'
  | 'chargeFilter'
  | 'trueUpParentFee'
  | 'charge'
>

/**
 * Minimum fields required from a subscription for fee display names
 */
type SubscriptionForDisplayName = Pick<AssociatedSubscription, 'plan'>

const _getFeeDisplayName = (
  fee: FeeForDisplayName,
  subscription: SubscriptionForDisplayName,
): string => {
  if (fee.feeType === FeeTypesEnum.Subscription) {
    return getSubscriptionFeeDisplayName(fee, subscription)
  }
  if (fee.feeType === FeeTypesEnum.FixedCharge) {
    return fee?.invoiceName || fee?.itemName
  }
  if (fee.feeType === FeeTypesEnum.Commitment) {
    return fee.invoiceDisplayName || 'Minimum commitment - True up'
  }
  if (!!fee?.trueUpParentFee?.id) {
    return (
      composeMultipleValuesWithSepator([
        fee.invoiceName || fee.charge?.billableMetric?.name,
        composeGroupedByDisplayName(fee.groupedBy),
        composeChargeFilterDisplayName(fee.chargeFilter),
      ]) + ' - True-up'
    )
  }

  if (!!fee.chargeFilter) {
    return (
      fee.invoiceDisplayName ||
      composeMultipleValuesWithSepator([
        fee.invoiceName || fee.charge?.billableMetric?.name,
        composeGroupedByDisplayName(fee.groupedBy),
        composeChargeFilterDisplayName(fee.chargeFilter),
      ])
    )
  }

  return (
    fee.invoiceDisplayName ||
    composeMultipleValuesWithSepator([
      fee.invoiceName || fee.charge?.billableMetric?.name,
      composeGroupedByDisplayName(fee.groupedBy),
    ])
  )
}

/**
 * Adds metadata to a fee
 * Generic function that works with any fee type having the required fields
 */
const _formatFeeWithMetadata = <TFee extends FeeForDisplayName>(
  fee: TFee,
  subscription: SubscriptionForDisplayName,
): TExtendedFee<TFee> => {
  return {
    ...fee,
    metadata: {
      displayName: _getFeeDisplayName(fee, subscription),
      isNormalFee: fee.feeType === FeeTypesEnum.Charge,
      isFixedCharge: fee.feeType === FeeTypesEnum.FixedCharge,
      isCommitmentFee: fee.feeType === FeeTypesEnum.Commitment,
      isTrueUpFee: !!fee.trueUpParentFee?.id,
      isFilterChildFee: !!fee.chargeFilter,
      isSubscriptionFee: fee.feeType === FeeTypesEnum.Subscription,
    },
  }
}

/**
 * Minimum fields required from a fee to group and format
 */
type FeeForGrouping = FeeForDisplayName &
  Pick<FeeFromFragment, 'id' | 'amountCents' | 'currency' | 'units' | 'subscription' | 'properties'>

/**
 * Groups and formats fees by subscription ID first, then by boundaries within each subscription
 *
 * @param fees Array of invoice fees with required fields
 * @param subscriptions Array of invoice subscriptions (needed for fee metadata and display names)
 * @param invoiceSubscriptions Array of invoice subscription join records (contains acceptNewChargeFees per subscription)
 * @param invoiceId Current invoice ID (used to match the correct invoiceSubscription record)
 * @returns An object containing fees grouped by subscription (with boundaries inside) and metadata
 *
 * @example
 * ```ts
 * groupAndFormatFees({
 *   fees: [...],
 *   subscriptions: [...],
 *   invoiceSubscriptions: invoice.invoiceSubscriptions,
 *   invoiceId: invoice.id,
 * })
 * Returns: {
 *   subscriptions: {
 *     [subscriptionId]: {
 *       acceptNewChargeFees: boolean
 *       boundaries: {
 *         [boundaryKey]: {
 *           fromDatetime: string
 *           toDatetime: string
 *           fees: [...TExtendedFee<...>]
 *         }
 *       }
 *       subscriptionDisplayName: string
 *     }
 *   }
 *   metadata: {
 *     hasAnyFeeParsed: boolean
 *     hasAnyPositiveFeeParsed: boolean
 *   }
 * }
 * ```
 */
export const groupAndFormatFees = <TFee extends FeeForGrouping>({
  fees,
  subscriptions,
  invoiceSubscriptions,
  invoiceId,
}: {
  fees: TFee[] | null | undefined
  subscriptions: AssociatedSubscription[] | null | undefined
  invoiceSubscriptions: AssociatedInvoiceSubscription[] | null | undefined
  invoiceId: string
}): {
  subscriptions: TSubscriptionDataForDisplay<TExtendedFee<TFee>>
  metadata: {
    hasAnyFeeParsed: boolean
    hasAnyPositiveFeeParsed: boolean
  }
} => {
  let hasAnyFeeParsed = false
  let hasAnyPositiveFeeParsed = false

  if (!fees?.length) {
    return {
      subscriptions: {},
      metadata: {
        hasAnyFeeParsed,
        hasAnyPositiveFeeParsed,
      },
    }
  }

  // First group by subscription ID, maintaining insertion order
  const feesGroupedBySubscription = fees.reduce<
    Record<
      string,
      {
        subscription: AssociatedSubscription
        boundaries: Record<
          string,
          { fromDatetime: string; toDatetime: string; fees: TExtendedFee<TFee>[] }
        >
      }
    >
  >((acc, fee) => {
    const subscriptionId = fee.subscription?.id

    // Skip fees without subscription ID (they belong to one-off invoices)
    if (!subscriptionId) return acc

    const associatedSubscription = subscriptions?.find((s) => s.id === subscriptionId)

    if (!associatedSubscription) return acc

    // Initialize subscription entry if it doesn't exist (maintains insertion order)
    if (!acc[subscriptionId]) {
      acc[subscriptionId] = {
        subscription: associatedSubscription,
        boundaries: {},
      }
    }

    // Create a unique key based on the fee's boundary dates
    const fromDatetime = fee.properties?.fromDatetime || ''
    const toDatetime = fee.properties?.toDatetime || ''
    const boundaryKey = createBoundaryKey(fromDatetime, toDatetime)

    // Initialize boundary entry if it doesn't exist
    if (!acc[subscriptionId].boundaries[boundaryKey]) {
      acc[subscriptionId].boundaries[boundaryKey] = {
        fromDatetime,
        toDatetime,
        fees: [],
      }
    }

    // Add the formatted fee to the boundary
    acc[subscriptionId].boundaries[boundaryKey].fees.push(
      _formatFeeWithMetadata(fee, associatedSubscription),
    )
    hasAnyFeeParsed = true

    if (fee.amountCents > 0) {
      hasAnyPositiveFeeParsed = true
    }

    return acc
  }, {})

  // Process each subscription: sort fees within boundaries, sort boundaries by date
  const result: TSubscriptionDataForDisplay<TExtendedFee<TFee>> = {}

  // Sort subscriptions by display name (subscription name or plan name)
  const sortedSubscriptionIds = Object.keys(feesGroupedBySubscription).sort((a, b) => {
    const subDataA = feesGroupedBySubscription[a]
    const subDataB = feesGroupedBySubscription[b]
    const displayNameA = (
      subDataA.subscription.name || subDataA.subscription.plan.name
    ).toLowerCase()
    const displayNameB = (
      subDataB.subscription.name || subDataB.subscription.plan.name
    ).toLowerCase()

    return displayNameA.localeCompare(displayNameB)
  })

  sortedSubscriptionIds.forEach((subscriptionId) => {
    const subscriptionData = feesGroupedBySubscription[subscriptionId]
    const { subscription, boundaries } = subscriptionData

    // Sort fees within each boundary
    Object.keys(boundaries).forEach((boundaryKey) => {
      const boundary = boundaries[boundaryKey]

      if (boundary?.fees?.length) {
        boundaries[boundaryKey].fees = _newDeepFormatFees(boundary.fees)
      }
    })

    // Sort boundaries by fromDatetime, then by toDatetime (earliest first)
    const sortedBoundaries: typeof boundaries = {}
    const sortedBoundaryKeys = Object.keys(boundaries).sort((a, b) => {
      const boundaryA = boundaries[a]
      const boundaryB = boundaries[b]

      // Compare fromDatetime first
      if (boundaryA.fromDatetime < boundaryB.fromDatetime) return -1
      if (boundaryA.fromDatetime > boundaryB.fromDatetime) return 1

      // If fromDatetime is equal, compare toDatetime
      if (boundaryA.toDatetime < boundaryB.toDatetime) return -1
      if (boundaryA.toDatetime > boundaryB.toDatetime) return 1

      return 0
    })

    // Rebuild boundaries with sorted keys
    sortedBoundaryKeys.forEach((key) => {
      sortedBoundaries[key] = boundaries[key]
    })

    // Create subscription display name
    const subscriptionDisplayName = subscription.name || subscription.plan.name

    // Find the acceptNewChargeFees value for this subscription from invoiceSubscriptions
    const invoiceSubscription = invoiceSubscriptions?.find(
      (invSub) => invSub.subscription.id === subscriptionId && invSub.invoice.id === invoiceId,
    )
    const acceptNewChargeFees = invoiceSubscription?.acceptNewChargeFees ?? false

    result[subscriptionId] = {
      acceptNewChargeFees,
      boundaries: sortedBoundaries,
      subscriptionDisplayName,
    }
  })

  return {
    subscriptions: result,
    metadata: {
      hasAnyFeeParsed,
      hasAnyPositiveFeeParsed,
    },
  }
}

/**
 * Sorts fees by type and display name
 * Works with any fee type that has metadata attached
 */
const _newDeepFormatFees = <T extends { metadata: FeeMetadata }>(feesToFormat: T[]): T[] => {
  return feesToFormat.sort((a, b) => {
    const aDisplayName = a?.metadata?.displayName.toLowerCase().replace('•', '').replace('-', '')
    const bDisplayName = b?.metadata?.displayName.toLowerCase().replace('•', '').replace('-', '')

    if (!!a?.metadata?.isSubscriptionFee && !b?.metadata?.isSubscriptionFee) {
      return -1
    } else if (!a?.metadata?.isSubscriptionFee && !!b?.metadata?.isSubscriptionFee) {
      return 1
    } else if (!!a?.metadata?.isFixedCharge && !b?.metadata?.isFixedCharge) {
      return -1
    } else if (!a?.metadata?.isFixedCharge && !!b?.metadata?.isFixedCharge) {
      return 1
    } else if (!!a?.metadata?.isCommitmentFee && !b?.metadata?.isCommitmentFee) {
      return 1
    } else if (!a?.metadata?.isCommitmentFee && !!b?.metadata?.isCommitmentFee) {
      return -1
    } else if (aDisplayName < bDisplayName) {
      return -1
    } else if (aDisplayName > bDisplayName) {
      return 1
    }
    return 0
  })
}
