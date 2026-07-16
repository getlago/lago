import { generatePath } from 'react-router-dom'

import { AvailableFiltersEnum, setFilterValue } from '~/components/designSystem/Filters'
import { ACTIVITY_LOG_ROUTE } from '~/components/developers/devtoolsRoutes'
import { ACTIVITY_LOG_FILTER_PREFIX } from '~/core/constants/filters'
import {
  BillableMetricDetailsTabsOptionsEnum,
  CouponDetailsTabsOptionsEnum,
  CustomerDetailsTabsOptions,
  CustomerInvoiceDetailsTabsOptionsEnum,
  FeatureDetailsTabsOptionsEnum,
  PlanDetailsTabsOptionsEnum,
} from '~/core/constants/tabsOptions'
import {
  BILLABLE_METRIC_DETAILS_ROUTE,
  BILLING_ENTITY_ROUTE,
  COUPON_DETAILS_ROUTE,
  CUSTOMER_DETAILS_TAB_ROUTE,
  CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE,
  CUSTOMER_INVOICE_DETAILS_ROUTE,
  FEATURE_DETAILS_ROUTE,
  PLAN_DETAILS_ROUTE,
} from '~/core/router'
import {
  ActivityLogDetailsFragment,
  ActivityTypeEnum,
  BillingEntity,
  CreditNote,
  Invoice,
  ResourceTypeEnum,
  Wallet,
} from '~/generated/graphql'

export function formatActivityType(activityType: ActivityTypeEnum) {
  const str = String(activityType)
  // List of known action suffixes
  const actions = [
    'payment_status_updated',
    'ready_to_finalize',
    'paid_credit_added',
    'refund_failure',
    'payment_failure',
    'payment_overdue',
    'one_off_created',
    'terminated',
    'generated',
    'created',
    'deleted',
    'updated',
    'drafted',
    'failed',
    'voided',
    'recorded',
    'started',
    'sent',
  ]

  for (const action of actions) {
    const suffix = `_${action}`

    if (str.endsWith(suffix)) {
      return `${str.slice(0, -suffix.length)}.${action}`
    }
  }
  return str
}

export function isDeletedActivityType(activityType: ActivityTypeEnum) {
  return activityType.endsWith('deleted')
}

/**
 * Pure mapping from an activity-log resource to the main-app path of its
 * detail page. Returns `null` when the resource has been deleted, when the
 * activityType is missing, or when the resource type is not linkable.
 */
export function getResourceLink(
  resource: ActivityLogDetailsFragment['resource'],
  {
    resourceType,
    activityType,
  }: {
    resourceType?: keyof typeof ResourceTypeEnum
    activityType?: ActivityTypeEnum
  },
): string | null {
  if (!resource) return null
  if (!activityType || isDeletedActivityType(activityType)) return null

  switch (resourceType) {
    case 'BillableMetric':
      return generatePath(BILLABLE_METRIC_DETAILS_ROUTE, {
        billableMetricId: resource.id,
        tab: BillableMetricDetailsTabsOptionsEnum.overview,
      })
    case 'BillingEntity':
      return generatePath(BILLING_ENTITY_ROUTE, {
        billingEntityCode: (resource as BillingEntity).code,
      })
    case 'Coupon':
      return generatePath(COUPON_DETAILS_ROUTE, {
        couponId: resource.id,
        tab: CouponDetailsTabsOptionsEnum.overview,
      })
    case 'CreditNote':
      if (!(resource as CreditNote).customer?.id || !(resource as CreditNote).invoice?.id) {
        return null
      }
      return generatePath(CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE, {
        customerId: (resource as CreditNote).customer?.id,
        invoiceId: (resource as CreditNote).invoice?.id as string | null,
        creditNoteId: resource.id,
      })
    case 'Invoice':
      return generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
        customerId: (resource as Invoice).customer?.id,
        invoiceId: resource.id,
        tab: CustomerInvoiceDetailsTabsOptionsEnum.overview,
      })
    case 'Feature':
      return generatePath(FEATURE_DETAILS_ROUTE, {
        featureId: resource.id,
        tab: FeatureDetailsTabsOptionsEnum.overview,
      })
    case 'Plan':
      return generatePath(PLAN_DETAILS_ROUTE, {
        planId: resource.id,
        tab: PlanDetailsTabsOptionsEnum.overview,
      })
    case 'Wallet':
      return generatePath(CUSTOMER_DETAILS_TAB_ROUTE, {
        // @ts-expect-error - walletCustomer is not typed in the graphql schema
        customerId: (resource as Wallet).walletCustomer?.id,
        tab: CustomerDetailsTabsOptions.wallet,
      })
    // Other resources are not linkable because they require more params in their URL
    default:
      return null
  }
}

export function buildLinkToActivityLog(activityId: string, filter?: AvailableFiltersEnum): string {
  const searchParams = new URLSearchParams()
  const path = generatePath(ACTIVITY_LOG_ROUTE, { logId: activityId })

  setFilterValue({
    searchParams,
    prefix: ACTIVITY_LOG_FILTER_PREFIX,
    key: filter ?? AvailableFiltersEnum.activityIds,
    value: activityId,
  })

  if (searchParams.size > 0) {
    return `${path}?${searchParams.toString()}`
  }

  return path
}
