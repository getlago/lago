import { DateTime } from 'luxon'

import { formatActivityType } from '~/components/activityLogs/utils'
import { IsCustomerTinEmptyEnum } from '~/components/designSystem/Filters/filtersElements/FiltersItemIsCustomerTinEmpty'
import {
  PeriodScopeTranslationLookup,
  TPeriodScopeTranslationLookupValue,
} from '~/components/graphs/MonthSelectorDropdown'
import {
  ACTIVITY_LOG_FILTER_PREFIX,
  ANALYTICS_INVOICES_FILTER_PREFIX,
  ANALYTICS_USAGE_BILLABLE_METRIC_FILTER_PREFIX,
  ANALYTICS_USAGE_OVERVIEW_FILTER_PREFIX,
  API_LOGS_FILTER_PREFIX,
  CREDIT_NOTE_LIST_FILTER_PREFIX,
  CUSTOMER_ANALYTICS_FILTER_PREFIX,
  CUSTOMER_CREDIT_NOTES_FILTER_PREFIX,
  CUSTOMER_LIST_FILTER_PREFIX,
  CUSTOMER_PAYMENTS_FILTER_PREFIX,
  FORECASTS_FILTER_PREFIX,
  INVOICE_LIST_FILTER_PREFIX,
  MRR_BREAKDOWN_OVERVIEW_FILTER_PREFIX,
  MRR_BREAKDOWN_PLANS_FILTER_PREFIX,
  ORDER_FORM_LIST_FILTER_PREFIX,
  ORDER_LIST_FILTER_PREFIX,
  PREPAID_CREDITS_OVERVIEW_FILTER_PREFIX,
  QUOTE_LIST_FILTER_PREFIX,
  REVENUE_STREAMS_BREAKDOWN_CUSTOMER_FILTER_PREFIX,
  REVENUE_STREAMS_BREAKDOWN_PLAN_FILTER_PREFIX,
  REVENUE_STREAMS_OVERVIEW_FILTER_PREFIX,
  SECURITY_LOGS_FILTER_PREFIX,
  SUBSCRIPTION_LIST_FILTER_PREFIX,
  WEBHOOK_LOGS_FILTER_PREFIX,
} from '~/core/constants/filters'
import { INVOICES_ROUTE } from '~/core/router'
import { DateFormat, intlFormatDateTime } from '~/core/timezone'
import {
  type ActivityLogsQueryVariables,
  ActivityTypeEnum,
  CurrencyEnum,
  type CustomerAccountTypeEnum,
  type CustomersQueryVariables,
  type GetApiLogsQueryVariables,
  type GetCreditNotesListQueryVariables,
  type GetForecastsQueryVariables,
  type GetInvoiceCollectionsForAnalyticsQueryVariables,
  type GetInvoicesListQueryVariables,
  type GetMrrsQueryVariables,
  type GetOrderFormsQueryVariables,
  type GetOrdersQueryVariables,
  type GetPrepaidCreditsQueryVariables,
  type GetQuotesQueryVariables,
  type GetRevenueStreamsQueryVariables,
  type GetSecurityLogsQueryVariables,
  type GetSubscriptionsListQueryVariables,
  type GetUsageBillableMetricQueryVariables,
  type GetUsageOverviewQueryVariables,
  type GetWebhookLogQueryVariables,
  InvoicePaymentStatusTypeEnum,
  InvoiceStatusTypeEnum,
} from '~/generated/graphql'
import { TranslateFunc } from '~/hooks/core/useInternationalization'

import {
  ACTIVE_SUBSCRIPTIONS_INTERVALS_TRANSLATION_MAP,
  ActiveSubscriptionsFilterInterval,
  ActivityLogsAvailableFilters,
  AMOUNT_INTERVALS_TRANSLATION_MAP,
  AmountFilterInterval,
  AnalyticsInvoicesAvailableFilters,
  ApiLogsAvailableFilters,
  AvailableFiltersEnum,
  CreditNoteAvailableFilters,
  CustomerAnalyticsAvailableFilters,
  CustomerAvailableFilters,
  CustomerCreditNotesAvailableFilters,
  CustomerInvoicesAvailableFilters,
  CustomerPaymentsAvailableFilters,
  filterDataInlineSeparator,
  filterDataLabelCommaPlaceholder,
  ForecastsAvailableFilters,
  InvoiceAvailableFilters,
  MrrBreakdownPlansAvailableFilters,
  MrrOverviewAvailableFilters,
  OrderAvailableFilters,
  OrderFormAvailableFilters,
  QuoteAvailableFilters,
  RevenueStreamsAvailablePopperFilters,
  RevenueStreamsCustomersAvailableFilters,
  RevenueStreamsPlansAvailableFilters,
  SecurityLogsAvailableFilters,
  SubscriptionAvailableFilters,
  UsageBillableMetricAvailableFilters,
  UsageOverviewAvailableFilters,
  WebhookLogsAvailableFilters,
} from './types'

export const keyWithPrefix = (key: string, prefix?: string) => (prefix ? `${prefix}_${key}` : key)

export const parseFromToValue = (value: string, keys: { from: string; to: string }) => {
  const [interval, from, to] = value.split(',')

  const fromAmount = from !== undefined && from !== '' ? Number(from) : null
  const toAmount = to !== undefined && to !== '' ? Number(to) : null

  switch (interval) {
    case AmountFilterInterval.isEqualTo:
      return {
        [keys.from]: fromAmount,
        [keys.to]: fromAmount,
      }
    case AmountFilterInterval.isBetween:
      return {
        [keys.from]: fromAmount,
        [keys.to]: toAmount,
      }
    case AmountFilterInterval.isUpTo:
    case ActiveSubscriptionsFilterInterval.isLessThan:
      return {
        [keys.from]: null,
        [keys.to]: toAmount,
      }
    case AmountFilterInterval.isAtLeast:
    case ActiveSubscriptionsFilterInterval.isGreaterThan:
      return {
        [keys.from]: fromAmount,
        [keys.to]: null,
      }
    default:
      return {
        [keys.from]: null,
        [keys.to]: null,
      }
  }
}

export const METADATA_SPLITTER = '&'

export const parseMetadataFilter = (value: string) => {
  if (!value) {
    return []
  }

  return value.split(METADATA_SPLITTER).map((metadata) => {
    const [key, val] = metadata.split('=')

    return { key, value: val || '' }
  })
}

export const formatMetadataFilter = (metadata: { key: string; value: string }[]) => {
  return metadata
    .map((item) => (item.value ? `${item.key}=${item.value}` : `${item.key}=`))
    .join(METADATA_SPLITTER)
}

/**
 * Multiple-value filters join selections with a comma; the display label embedded after
 * `filterDataInlineSeparator` (a customer/entity name, an email) can itself contain commas.
 * escapeFilterLabel encodes those commas at storage time so a single selection never
 * over-splits; unescapeFilterLabel restores them for display. The id portion (before the
 * separator) is never escaped, so query decoding is unaffected.
 */
export const escapeFilterLabel = (label: string): string =>
  label.split(',').join(filterDataLabelCommaPlaceholder)

export const unescapeFilterLabel = (label: string): string =>
  label.split(filterDataLabelCommaPlaceholder).join(',')

export const FiltersItemDates = [
  AvailableFiltersEnum.date,
  AvailableFiltersEnum.issuingDate,
  AvailableFiltersEnum.loggedDate,
  AvailableFiltersEnum.webhookDate,
  AvailableFiltersEnum.quoteCreatedAt,
  AvailableFiltersEnum.orderFormCreatedAt,
  AvailableFiltersEnum.orderExecutedAt,
]

// TODO: Fix this type
// eslint-disable-next-line @typescript-eslint/no-unsafe-function-type
export const FILTER_VALUE_MAP: Record<AvailableFiltersEnum, Function> = {
  [AvailableFiltersEnum.activityIds]: (value: string) => value.split(',').map((v) => v.trim()),
  [AvailableFiltersEnum.activitySources]: (value: string) => (value as string).split(','),
  [AvailableFiltersEnum.activityTypes]: (value: string) => (value as string).split(','),
  [AvailableFiltersEnum.activeSubscriptions]: (value: string) =>
    parseFromToValue(value, { from: 'activeSubscriptionsFrom', to: 'activeSubscriptionsTo' }),
  [AvailableFiltersEnum.amount]: (value: string) =>
    parseFromToValue(value, { from: 'amountFrom', to: 'amountTo' }),
  [AvailableFiltersEnum.apiKeyIds]: (value: string) =>
    value.split(',').map((v) => v.split(filterDataInlineSeparator)[0]),
  [AvailableFiltersEnum.billingEntityIds]: (value: string) =>
    (value as string).split(',').map((v) => v.split(filterDataInlineSeparator)[0]),
  [AvailableFiltersEnum.billingEntityId]: (value: string) =>
    value.split(filterDataInlineSeparator)[0],
  [AvailableFiltersEnum.billingEntityCode]: (value: string) => value,
  [AvailableFiltersEnum.country]: (value: string) => value,
  [AvailableFiltersEnum.countries]: (value: string) =>
    (value as string).split(',').map((v) => v.split(filterDataInlineSeparator)[0]),
  [AvailableFiltersEnum.creditNoteCreditStatus]: (value: string) => (value as string).split(','),
  [AvailableFiltersEnum.creditNoteReason]: (value: string) => (value as string).split(','),
  [AvailableFiltersEnum.creditNoteRefundStatus]: (value: string) => (value as string).split(','),
  [AvailableFiltersEnum.creditNoteType]: (value: string) => (value as string).split(','),
  [AvailableFiltersEnum.currency]: (value: string) => value,
  [AvailableFiltersEnum.currencies]: (value: string) =>
    (value as string).split(',').map((v) => v.split(filterDataInlineSeparator)[0]),
  [AvailableFiltersEnum.customerType]: (value: string) => value,
  [AvailableFiltersEnum.customerAccountType]: (value: string) => value,
  [AvailableFiltersEnum.customerExternalId]: (value: string) =>
    (value as string).split(filterDataInlineSeparator)[0],
  [AvailableFiltersEnum.externalId]: (value: string) => value,
  [AvailableFiltersEnum.isCustomerTinEmpty]: (value: string) =>
    value !== IsCustomerTinEmptyEnum.True,
  [AvailableFiltersEnum.date]: (value: string) => {
    return { fromDate: (value as string).split(',')[0], toDate: (value as string).split(',')[1] }
  },
  [AvailableFiltersEnum.hasCustomerType]: (value: string) => value === 'true',
  [AvailableFiltersEnum.httpMethods]: (value: string) => (value as string).split(','),
  [AvailableFiltersEnum.httpStatuses]: (value: string) => (value as string).split(','),
  [AvailableFiltersEnum.invoiceNumber]: (value: string) => value,
  [AvailableFiltersEnum.invoiceType]: (value: string) => (value as string).split(','),
  [AvailableFiltersEnum.issuingDate]: (value: string) => {
    return {
      issuingDateFrom: (value as string).split(',')[0],
      issuingDateTo: (value as string).split(',')[1],
    }
  },
  [AvailableFiltersEnum.loggedDate]: (value: string) => {
    return {
      fromDate: (value as string).split(',')[0] || undefined,
      toDate: (value as string).split(',')[1] || undefined,
    }
  },
  [AvailableFiltersEnum.logEvents]: (value: string) => value.split(',').filter(Boolean),
  [AvailableFiltersEnum.logTypes]: (value: string) => value.split(',').filter(Boolean),
  [AvailableFiltersEnum.metadata]: (value: string) => parseMetadataFilter(value),
  [AvailableFiltersEnum.multipleCustomers]: (value: string) =>
    value.split(',').map((v) => v.split(filterDataInlineSeparator)[0]),
  [AvailableFiltersEnum.overriden]: (value: string) => value === 'true',
  [AvailableFiltersEnum.partiallyPaid]: (value: string) => value === 'true',
  [AvailableFiltersEnum.paymentDisputeLost]: (value: string) => value === 'true',
  [AvailableFiltersEnum.paymentOverdue]: (value: string) => value === 'true',
  [AvailableFiltersEnum.paymentStatus]: (value: string) => (value as string).split(','),
  [AvailableFiltersEnum.planCode]: (value: string) => value,
  [AvailableFiltersEnum.orderFormCreatedAt]: (value: string) => {
    return {
      createdAtFrom: value.split(',')[0],
      createdAtTo: value.split(',')[1],
    }
  },
  [AvailableFiltersEnum.orderFormNumber]: (value: string) => value.split(','),
  [AvailableFiltersEnum.orderFormStatus]: (value: string) => value.split(','),
  [AvailableFiltersEnum.orderStatus]: (value: string) => value.split(','),
  [AvailableFiltersEnum.orderNumber]: (value: string) => value.split(','),
  [AvailableFiltersEnum.orderExecutionMode]: (value: string) => value.split(','),
  [AvailableFiltersEnum.orderExecutedAt]: (value: string) => {
    return {
      executedAtFrom: value.split(',')[0],
      executedAtTo: value.split(',')[1],
    }
  },
  [AvailableFiltersEnum.quoteCreatedAt]: (value: string) => {
    return {
      fromDate: value.split(',')[0],
      toDate: value.split(',')[1],
    }
  },
  [AvailableFiltersEnum.quoteNumber]: (value: string) => value.split(','),
  [AvailableFiltersEnum.quoteOrderType]: (value: string) => value.split(','),
  [AvailableFiltersEnum.quoteStatus]: (value: string) => value.split(','),
  [AvailableFiltersEnum.requestPaths]: (value: string) => value.split(',').map((v) => v.trim()),
  [AvailableFiltersEnum.resourceIds]: (value: string) => value.split(',').map((v) => v.trim()),
  [AvailableFiltersEnum.resourceTypes]: (value: string) => (value as string).split(','),
  [AvailableFiltersEnum.selfBilled]: (value: string) => value === 'true',
  [AvailableFiltersEnum.settlementType]: (value: string) => (value as string).split(','),
  [AvailableFiltersEnum.states]: (value: string) =>
    (value as string).split(',').map((v) => v.split(filterDataInlineSeparator)[0]),
  [AvailableFiltersEnum.status]: (value: string) => (value as string).split(','),
  [AvailableFiltersEnum.subscriptionExternalId]: (value: string) =>
    (value as string).split(filterDataInlineSeparator)[0],
  [AvailableFiltersEnum.subscriptionStatus]: (value: string) => (value as string).split(','),
  [AvailableFiltersEnum.timeGranularity]: (value: string) => value,
  [AvailableFiltersEnum.period]: (value: string) => value,
  [AvailableFiltersEnum.userEmails]: (value: string) => value.split(',').map((v) => v.trim()),
  [AvailableFiltersEnum.webhookDate]: (value: string) => {
    return {
      fromDate: (value as string).split(',')[0] || undefined,
      toDate: (value as string).split(',')[1] || undefined,
    }
  },
  [AvailableFiltersEnum.webhookEventTypes]: (value: string) => (value as string).split(','),
  [AvailableFiltersEnum.webhookHttpStatuses]: (value: string) => (value as string).split(','),
  [AvailableFiltersEnum.userIds]: (value: string) =>
    value
      .split(',')
      .filter(Boolean)
      .map((v) => v.split(filterDataInlineSeparator)[0]),
  [AvailableFiltersEnum.webhookStatus]: (value: string) => (value as string).split(','),
  [AvailableFiltersEnum.zipcodes]: (value: string) =>
    (value as string).split(',').map((v) => v.split(filterDataInlineSeparator)[0]),
  [AvailableFiltersEnum.billableMetricCode]: (value: string) => value,
}

// NOTE: this is fixing list fetching issue when new item are added to the DB and user scrolls to the bottom of the list
// In that case, we fetch new elements and display between older ones
// This is due to the pagination system, using pages instead of cursors
// This workaround is to set the default toDate value to the current time, hence enforcing a fake cursor
// The toDate is the minimum date between the fromDate and the current time
export const defineDefaultToDateValue = (
  searchParams: URLSearchParams,
  filtersNamePrefix: string,
  dateFilterKey: AvailableFiltersEnum = AvailableFiltersEnum.loggedDate,
): URLSearchParams => {
  // Truncate to the second to produce a stable value within the same second.
  // Without this, consecutive calls return different millisecond-precision timestamps,
  // causing Apollo to see different query variables and cancel+re-fire the request.
  const now = DateTime.now().startOf('second')
  const searchParamsCopy = new URLSearchParams(searchParams)

  const searchParamsLoggedDateEntryKey = keyWithPrefix(dateFilterKey, filtersNamePrefix)
  const searchParamsLoggedDateEntryValue: string | undefined = Object.fromEntries(
    searchParamsCopy.entries(),
  )[searchParamsLoggedDateEntryKey]

  if (!searchParamsLoggedDateEntryValue) {
    searchParamsCopy.set(searchParamsLoggedDateEntryKey, `,${now.toISO()}`)
    return searchParamsCopy
  }

  const [fromDate, toDate = now.toISO()] = searchParamsLoggedDateEntryValue.split(',')
  const dateToEndOfDay = DateTime.fromISO(toDate).endOf('day')

  const earliestToDateVsNow = dateToEndOfDay < now ? dateToEndOfDay.toISO() : now.toISO()

  searchParamsCopy.set(searchParamsLoggedDateEntryKey, `${fromDate},${earliestToDateVsNow}`)

  return searchParamsCopy
}

export type TformatFiltersForQueryReturn = {
  [key: string]: string | string[] | boolean
}

export const formatFiltersForQuery = <T = TformatFiltersForQueryReturn>({
  searchParams,
  keyMap,
  availableFilters,
  filtersNamePrefix,
}: {
  searchParams: URLSearchParams
  keyMap?: Partial<Record<AvailableFiltersEnum, keyof T & string>>
  availableFilters: AvailableFiltersEnum[]
  filtersNamePrefix: string
}): T => {
  const filtersSetInUrl = Object.fromEntries(searchParams.entries())

  return Object.entries(filtersSetInUrl).reduce(
    (acc, cur) => {
      const current = cur as [AvailableFiltersEnum, string | string[] | boolean]
      const _key = current[0]

      const key = (
        filtersNamePrefix ? _key.replace(`${filtersNamePrefix}_`, '') : _key
      ) as AvailableFiltersEnum

      if (!availableFilters.includes(key)) {
        return acc
      }

      const filterFunction = FILTER_VALUE_MAP[key]

      const value = filterFunction ? filterFunction(current[1]) : current[1]

      if (typeof value === 'object' && !Array.isArray(value) && value !== null) {
        return {
          ...acc,
          ...value,
        }
      }

      return {
        ...acc,
        [keyMap?.[key] || key]: value,
      }
    },
    {} as Record<string, unknown>,
  ) as T
}

type CreditNotesQueryFilters = Partial<
  Pick<
    GetCreditNotesListQueryVariables,
    | 'amountFrom'
    | 'amountTo'
    | 'creditStatus'
    | 'currency'
    | 'customerExternalId'
    | 'invoiceNumber'
    | 'issuingDateFrom'
    | 'issuingDateTo'
    | 'reason'
    | 'refundStatus'
    | 'types'
    | 'selfBilled'
    | 'billingEntityIds'
  >
>

export const formatFiltersForCreditNotesQuery = (
  searchParams: URLSearchParams,
): CreditNotesQueryFilters => {
  const keyMap: Partial<Record<AvailableFiltersEnum, keyof CreditNotesQueryFilters & string>> = {
    [AvailableFiltersEnum.creditNoteReason]: 'reason',
    [AvailableFiltersEnum.creditNoteCreditStatus]: 'creditStatus',
    [AvailableFiltersEnum.creditNoteRefundStatus]: 'refundStatus',
    [AvailableFiltersEnum.creditNoteType]: 'types',
  }

  return formatFiltersForQuery<CreditNotesQueryFilters>({
    searchParams,
    keyMap,
    availableFilters: CreditNoteAvailableFilters,
    filtersNamePrefix: CREDIT_NOTE_LIST_FILTER_PREFIX,
  })
}

type InvoiceQueryFilters = Partial<
  Pick<
    GetInvoicesListQueryVariables,
    | 'currency'
    | 'customerExternalId'
    | 'invoiceType'
    | 'issuingDateFrom'
    | 'issuingDateTo'
    | 'partiallyPaid'
    | 'paymentDisputeLost'
    | 'paymentOverdue'
    | 'paymentStatus'
    | 'settlements'
    | 'status'
    | 'amountFrom'
    | 'amountTo'
    | 'selfBilled'
    | 'billingEntityIds'
  >
>

export const formatFiltersForInvoiceQuery = (
  searchParams: URLSearchParams,
): InvoiceQueryFilters => {
  const keyMap: Partial<Record<AvailableFiltersEnum, keyof InvoiceQueryFilters & string>> = {
    [AvailableFiltersEnum.settlementType]: 'settlements',
  }

  return formatFiltersForQuery<InvoiceQueryFilters>({
    searchParams,
    keyMap,
    availableFilters: InvoiceAvailableFilters,
    filtersNamePrefix: INVOICE_LIST_FILTER_PREFIX,
  })
}

type CustomerQueryFilters = Partial<
  Pick<
    CustomersQueryVariables,
    | 'billingEntityIds'
    | 'activeSubscriptionsCountFrom'
    | 'activeSubscriptionsCountTo'
    | 'customerType'
    | 'countries'
    | 'currencies'
    | 'externalId'
    | 'states'
    | 'zipcodes'
    | 'hasTaxIdentificationNumber'
    | 'hasCustomerType'
    | 'metadata'
  >
> & { accountType?: CustomerAccountTypeEnum }

export const formatFiltersForCustomerQuery = (
  searchParams: URLSearchParams,
): CustomerQueryFilters => {
  const formatted = formatFiltersForQuery<
    CustomerQueryFilters & {
      activeSubscriptionsFrom?: number | null
      activeSubscriptionsTo?: number | null
      isCustomerTinEmpty?: boolean
    }
  >({
    searchParams,
    availableFilters: CustomerAvailableFilters,
    filtersNamePrefix: CUSTOMER_LIST_FILTER_PREFIX,
  })

  if (
    formatted.activeSubscriptionsFrom !== undefined &&
    formatted.activeSubscriptionsFrom !== null
  ) {
    formatted.activeSubscriptionsCountFrom = formatted.activeSubscriptionsFrom
    delete formatted.activeSubscriptionsFrom
  }

  if (formatted.activeSubscriptionsTo !== undefined && formatted.activeSubscriptionsTo !== null) {
    formatted.activeSubscriptionsCountTo = formatted.activeSubscriptionsTo
    delete formatted.activeSubscriptionsTo
  }

  // isCustomerTinEmpty is used in analytics filter but is basically the opposite of hasTaxIdentificationNumber used in customer list query
  if (typeof formatted.isCustomerTinEmpty === 'boolean') {
    formatted.hasTaxIdentificationNumber = !formatted.isCustomerTinEmpty
    delete formatted.isCustomerTinEmpty
  }

  return formatted
}

type SubscriptionQueryFilters = Partial<
  Pick<
    GetSubscriptionsListQueryVariables,
    'status' | 'externalCustomerId' | 'externalId' | 'overriden' | 'planCode' | 'billingEntityIds'
  >
>

export const formatFiltersForSubscriptionQuery = (
  searchParams: URLSearchParams,
): SubscriptionQueryFilters => {
  const keyMap: Partial<Record<AvailableFiltersEnum, keyof SubscriptionQueryFilters & string>> = {
    [AvailableFiltersEnum.subscriptionStatus]: 'status',
    [AvailableFiltersEnum.customerExternalId]: 'externalCustomerId',
  }

  return formatFiltersForQuery<SubscriptionQueryFilters>({
    keyMap,
    searchParams,
    availableFilters: SubscriptionAvailableFilters,
    filtersNamePrefix: SUBSCRIPTION_LIST_FILTER_PREFIX,
  })
}

export const formatFiltersForCustomerAnalyticsQuery = (
  searchParams: URLSearchParams,
): { currency?: CurrencyEnum; billingEntityId?: string } => {
  return formatFiltersForQuery<{ currency?: CurrencyEnum; billingEntityId?: string }>({
    searchParams,
    availableFilters: CustomerAnalyticsAvailableFilters,
    filtersNamePrefix: CUSTOMER_ANALYTICS_FILTER_PREFIX,
  })
}

export const formatFiltersForCustomerInvoicesQuery = (
  searchParams: URLSearchParams,
  filtersNamePrefix: string,
): { currency?: CurrencyEnum; billingEntityId?: string } => {
  return formatFiltersForQuery<{ currency?: CurrencyEnum; billingEntityId?: string }>({
    searchParams,
    availableFilters: CustomerInvoicesAvailableFilters,
    filtersNamePrefix,
  })
}

export const formatFiltersForCustomerPaymentsQuery = (
  searchParams: URLSearchParams,
): { currency?: CurrencyEnum } => {
  return formatFiltersForQuery<{ currency?: CurrencyEnum }>({
    searchParams,
    availableFilters: CustomerPaymentsAvailableFilters,
    filtersNamePrefix: CUSTOMER_PAYMENTS_FILTER_PREFIX,
  })
}

export const formatFiltersForCustomerCreditNotesQuery = (
  searchParams: URLSearchParams,
): { currency?: CurrencyEnum; billingEntityId?: string } => {
  return formatFiltersForQuery<{ currency?: CurrencyEnum; billingEntityId?: string }>({
    searchParams,
    availableFilters: CustomerCreditNotesAvailableFilters,
    filtersNamePrefix: CUSTOMER_CREDIT_NOTES_FILTER_PREFIX,
  })
}

type RevenueStreamsQueryFilters = Partial<
  Pick<
    GetRevenueStreamsQueryVariables,
    | 'currency'
    | 'customerCountry'
    | 'customerType'
    | 'isCustomerTinEmpty'
    | 'externalCustomerId'
    | 'externalSubscriptionId'
    | 'fromDate'
    | 'toDate'
    | 'planCode'
    | 'timeGranularity'
    | 'billingEntityCode'
  >
>

export const formatFiltersForRevenueStreamsQuery = (
  searchParams: URLSearchParams,
): RevenueStreamsQueryFilters => {
  const keyMap: Partial<Record<AvailableFiltersEnum, keyof RevenueStreamsQueryFilters & string>> = {
    [AvailableFiltersEnum.country]: 'customerCountry',
    [AvailableFiltersEnum.customerType]: 'customerType',
    [AvailableFiltersEnum.customerExternalId]: 'externalCustomerId',
    [AvailableFiltersEnum.subscriptionExternalId]: 'externalSubscriptionId',
  }

  return formatFiltersForQuery<RevenueStreamsQueryFilters>({
    keyMap,
    searchParams,
    availableFilters: [
      ...RevenueStreamsAvailablePopperFilters,
      AvailableFiltersEnum.timeGranularity,
    ],
    filtersNamePrefix: REVENUE_STREAMS_OVERVIEW_FILTER_PREFIX,
  })
}

export const formatFiltersForRevenueStreamsPlansQuery = (
  searchParams: URLSearchParams,
): { currency?: CurrencyEnum } => {
  return formatFiltersForQuery<{ currency?: CurrencyEnum }>({
    searchParams,
    availableFilters: RevenueStreamsPlansAvailableFilters,
    filtersNamePrefix: REVENUE_STREAMS_BREAKDOWN_PLAN_FILTER_PREFIX,
  })
}

type MrrQueryFilters = Partial<
  Pick<
    GetMrrsQueryVariables,
    | 'currency'
    | 'customerCountry'
    | 'customerType'
    | 'isCustomerTinEmpty'
    | 'externalCustomerId'
    | 'fromDate'
    | 'toDate'
    | 'timeGranularity'
    | 'billingEntityCode'
  >
>

export const formatFiltersForMrrQuery = (searchParams: URLSearchParams): MrrQueryFilters => {
  const keyMap: Partial<Record<AvailableFiltersEnum, keyof MrrQueryFilters & string>> = {
    [AvailableFiltersEnum.country]: 'customerCountry',
    [AvailableFiltersEnum.customerType]: 'customerType',
    [AvailableFiltersEnum.customerExternalId]: 'externalCustomerId',
  }

  return formatFiltersForQuery<MrrQueryFilters>({
    keyMap,
    searchParams,
    availableFilters: [...MrrOverviewAvailableFilters, AvailableFiltersEnum.timeGranularity],
    filtersNamePrefix: MRR_BREAKDOWN_OVERVIEW_FILTER_PREFIX,
  })
}

export const formatFiltersForMrrPlansQuery = (
  searchParams: URLSearchParams,
): { currency?: CurrencyEnum } => {
  return formatFiltersForQuery<{ currency?: CurrencyEnum }>({
    searchParams,
    availableFilters: MrrBreakdownPlansAvailableFilters,
    filtersNamePrefix: MRR_BREAKDOWN_PLANS_FILTER_PREFIX,
  })
}

export const formatFiltersForRevenueStreamsCustomersQuery = (
  searchParams: URLSearchParams,
): { currency?: CurrencyEnum } => {
  return formatFiltersForQuery<{ currency?: CurrencyEnum }>({
    searchParams,
    availableFilters: RevenueStreamsCustomersAvailableFilters,
    filtersNamePrefix: REVENUE_STREAMS_BREAKDOWN_CUSTOMER_FILTER_PREFIX,
  })
}

type PrepaidCreditsQueryFilters = Partial<
  Pick<
    GetPrepaidCreditsQueryVariables,
    | 'currency'
    | 'customerCountry'
    | 'customerType'
    | 'isCustomerTinEmpty'
    | 'externalCustomerId'
    | 'fromDate'
    | 'toDate'
    | 'timeGranularity'
    | 'billingEntityCode'
  >
>

export const formatFiltersForPrepaidCreditsQuery = (
  searchParams: URLSearchParams,
): PrepaidCreditsQueryFilters => {
  const keyMap: Partial<Record<AvailableFiltersEnum, keyof PrepaidCreditsQueryFilters & string>> = {
    [AvailableFiltersEnum.country]: 'customerCountry',
    [AvailableFiltersEnum.customerAccountType]: 'customerType',
    [AvailableFiltersEnum.customerExternalId]: 'externalCustomerId',
  }

  return formatFiltersForQuery<PrepaidCreditsQueryFilters>({
    keyMap,
    searchParams,
    availableFilters: [...MrrOverviewAvailableFilters, AvailableFiltersEnum.timeGranularity],
    filtersNamePrefix: PREPAID_CREDITS_OVERVIEW_FILTER_PREFIX,
  })
}

type AnalyticsInvoicesQueryFilters = Partial<
  Pick<
    GetInvoiceCollectionsForAnalyticsQueryVariables,
    'currency' | 'billingEntityCode' | 'isCustomerTinEmpty'
  >
> & { period?: string }

export const formatFiltersForAnalyticsInvoicesQuery = (
  searchParams: URLSearchParams,
): AnalyticsInvoicesQueryFilters => {
  return formatFiltersForQuery<AnalyticsInvoicesQueryFilters>({
    searchParams,
    availableFilters: AnalyticsInvoicesAvailableFilters,
    filtersNamePrefix: ANALYTICS_INVOICES_FILTER_PREFIX,
  })
}

type WebhookLogsQueryFilters = Partial<
  Pick<
    GetWebhookLogQueryVariables,
    'statuses' | 'eventTypes' | 'httpStatuses' | 'fromDate' | 'toDate'
  >
>

export const formatFiltersForWebhookLogsQuery = (
  searchParams: URLSearchParams,
): WebhookLogsQueryFilters => {
  const keyMap: Partial<Record<AvailableFiltersEnum, keyof WebhookLogsQueryFilters & string>> = {
    [AvailableFiltersEnum.webhookStatus]: 'statuses',
    [AvailableFiltersEnum.webhookEventTypes]: 'eventTypes',
    [AvailableFiltersEnum.webhookHttpStatuses]: 'httpStatuses',
  }

  return formatFiltersForQuery<WebhookLogsQueryFilters>({
    searchParams: defineDefaultToDateValue(
      searchParams,
      WEBHOOK_LOGS_FILTER_PREFIX,
      AvailableFiltersEnum.webhookDate,
    ),
    keyMap,
    availableFilters: WebhookLogsAvailableFilters,
    filtersNamePrefix: WEBHOOK_LOGS_FILTER_PREFIX,
  })
}

type UsageOverviewQueryFilters = Partial<
  Pick<
    GetUsageOverviewQueryVariables,
    | 'currency'
    | 'customerCountry'
    | 'customerType'
    | 'isCustomerTinEmpty'
    | 'externalCustomerId'
    | 'externalSubscriptionId'
    | 'fromDate'
    | 'toDate'
    | 'planCode'
    | 'timeGranularity'
    | 'billingEntityCode'
  >
>

export const formatFiltersForUsageOverviewQuery = (
  searchParams: URLSearchParams,
): UsageOverviewQueryFilters => {
  const keyMap: Partial<Record<AvailableFiltersEnum, keyof UsageOverviewQueryFilters & string>> = {
    [AvailableFiltersEnum.country]: 'customerCountry',
    [AvailableFiltersEnum.customerAccountType]: 'customerType',
    [AvailableFiltersEnum.customerExternalId]: 'externalCustomerId',
    [AvailableFiltersEnum.subscriptionExternalId]: 'externalSubscriptionId',
  }

  return formatFiltersForQuery<UsageOverviewQueryFilters>({
    keyMap,
    searchParams,
    availableFilters: [...UsageOverviewAvailableFilters, AvailableFiltersEnum.timeGranularity],
    filtersNamePrefix: ANALYTICS_USAGE_OVERVIEW_FILTER_PREFIX,
  })
}

type UsageBillableMetricQueryFilters = Partial<
  Pick<GetUsageBillableMetricQueryVariables, 'currency' | 'timeGranularity' | 'fromDate' | 'toDate'>
>

export const formatFiltersForUsageBillableMetricQuery = (
  searchParams: URLSearchParams,
): UsageBillableMetricQueryFilters => {
  return formatFiltersForQuery<UsageBillableMetricQueryFilters>({
    searchParams,
    availableFilters: [
      ...UsageBillableMetricAvailableFilters,
      AvailableFiltersEnum.timeGranularity,
    ],
    filtersNamePrefix: ANALYTICS_USAGE_BILLABLE_METRIC_FILTER_PREFIX,
  })
}

type ForecastsQueryFilters = Partial<
  Pick<
    GetForecastsQueryVariables,
    | 'billableMetricCode'
    | 'billingEntityCode'
    | 'currency'
    | 'customerCountry'
    | 'customerType'
    | 'externalCustomerId'
    | 'externalSubscriptionId'
    | 'isCustomerTinEmpty'
    | 'planCode'
    | 'timeGranularity'
  >
>

export const formatFiltersForForecastsQuery = (
  searchParams: URLSearchParams,
): ForecastsQueryFilters => {
  const keyMap: Partial<Record<AvailableFiltersEnum, keyof ForecastsQueryFilters & string>> = {
    [AvailableFiltersEnum.country]: 'customerCountry',
    [AvailableFiltersEnum.customerType]: 'customerType',
    [AvailableFiltersEnum.customerExternalId]: 'externalCustomerId',
    [AvailableFiltersEnum.subscriptionExternalId]: 'externalSubscriptionId',
  }

  return formatFiltersForQuery<ForecastsQueryFilters>({
    keyMap,
    searchParams,
    availableFilters: [...ForecastsAvailableFilters, AvailableFiltersEnum.timeGranularity],
    filtersNamePrefix: FORECASTS_FILTER_PREFIX,
  })
}

type ActivityLogsQueryFilters = Partial<
  Pick<
    ActivityLogsQueryVariables,
    | 'activityIds'
    | 'activitySources'
    | 'activityTypes'
    | 'apiKeyIds'
    | 'externalCustomerId'
    | 'externalSubscriptionId'
    | 'fromDate'
    | 'toDate'
    | 'resourceIds'
    | 'resourceTypes'
    | 'userEmails'
  >
>

export const formatFiltersForActivityLogsQuery = (
  searchParams: URLSearchParams,
): ActivityLogsQueryFilters => {
  const formatted = formatFiltersForQuery<
    ActivityLogsQueryFilters & {
      customerExternalId?: string
      subscriptionExternalId?: string
    }
  >({
    searchParams: defineDefaultToDateValue(searchParams, ACTIVITY_LOG_FILTER_PREFIX),
    availableFilters: ActivityLogsAvailableFilters,
    filtersNamePrefix: ACTIVITY_LOG_FILTER_PREFIX,
  })

  if (formatted.customerExternalId) {
    formatted.externalCustomerId = formatted.customerExternalId
    delete formatted.customerExternalId
  }
  if (formatted.subscriptionExternalId) {
    formatted.externalSubscriptionId = formatted.subscriptionExternalId
    delete formatted.subscriptionExternalId
  }

  return formatted
}

type ApiLogsQueryFilters = Partial<
  Pick<
    GetApiLogsQueryVariables,
    'fromDate' | 'toDate' | 'apiKeyIds' | 'httpMethods' | 'httpStatuses' | 'requestPaths'
  >
>

export const formatFiltersForApiLogsQuery = (
  searchParams: URLSearchParams,
): ApiLogsQueryFilters => {
  return formatFiltersForQuery<ApiLogsQueryFilters>({
    searchParams: defineDefaultToDateValue(searchParams, API_LOGS_FILTER_PREFIX),
    availableFilters: ApiLogsAvailableFilters,
    filtersNamePrefix: API_LOGS_FILTER_PREFIX,
  })
}

export const formatActiveFilterValueDisplay = (
  key: AvailableFiltersEnum,
  value: string,
  translate?: TranslateFunc,
): string => {
  if (key === AvailableFiltersEnum.amount) {
    const [interval, from, to] = value.split(',')

    const intervalLabel = translate?.(
      AMOUNT_INTERVALS_TRANSLATION_MAP[interval as AmountFilterInterval],
    )

    const isEqual = interval === AmountFilterInterval.isEqualTo

    const and =
      interval === AmountFilterInterval.isBetween
        ? translate?.('text_65f8472df7593301061e27d6').toLowerCase()
        : ''

    return `${intervalLabel} ${from || ''} ${and} ${isEqual ? '' : to || ''}`
  }

  if (key === AvailableFiltersEnum.activeSubscriptions) {
    const [interval, from, to] = value.split(',')

    const intervalLabel = translate?.(
      ACTIVE_SUBSCRIPTIONS_INTERVALS_TRANSLATION_MAP[interval as ActiveSubscriptionsFilterInterval],
    )

    const isEqual = interval === ActiveSubscriptionsFilterInterval.isEqualTo

    const and =
      interval === ActiveSubscriptionsFilterInterval.isBetween
        ? translate?.('text_65f8472df7593301061e27d6').toLowerCase()
        : ''

    return `${intervalLabel} ${from || ''} ${and} ${isEqual ? '' : to || ''}`
  }

  switch (key) {
    case AvailableFiltersEnum.activityTypes:
      return value
        .split(',')
        .map((v) => formatActivityType(v as ActivityTypeEnum))
        .join(', ')
    case AvailableFiltersEnum.customerExternalId:
    case AvailableFiltersEnum.billingEntityId:
      return unescapeFilterLabel(
        value.split(filterDataInlineSeparator)[1] || value.split(filterDataInlineSeparator)[0],
      )
    case AvailableFiltersEnum.isCustomerTinEmpty:
      return (
        translate?.(
          value === IsCustomerTinEmptyEnum.True
            ? 'text_17440181167432q7jzt9znuh'
            : 'text_1744018116743ntlygtcnq95',
        ) || ''
      )
    case AvailableFiltersEnum.date:
    case AvailableFiltersEnum.issuingDate:
    case AvailableFiltersEnum.loggedDate:
    case AvailableFiltersEnum.webhookDate:
    case AvailableFiltersEnum.quoteCreatedAt:
    case AvailableFiltersEnum.orderFormCreatedAt:
    case AvailableFiltersEnum.orderExecutedAt:
      return value
        .split(',')
        .map((v) => {
          return intlFormatDateTime(v, { formatDate: DateFormat.DATE_SHORT }).date
        })
        .join(' - ')
    case AvailableFiltersEnum.period:
      return (
        translate?.(PeriodScopeTranslationLookup[value as TPeriodScopeTranslationLookupValue]) || ''
      )
    case AvailableFiltersEnum.apiKeyIds:
    case AvailableFiltersEnum.billingEntityIds:
    case AvailableFiltersEnum.userIds:
    case AvailableFiltersEnum.multipleCustomers:
      return value
        .split(',')
        .map((v) =>
          unescapeFilterLabel(
            v.split(filterDataInlineSeparator)[1] || v.split(filterDataInlineSeparator)[0],
          ),
        )
        .join(', ')
    case AvailableFiltersEnum.userEmails:
      return value.toLocaleLowerCase()
    case AvailableFiltersEnum.billableMetricCode:
      return value
    case AvailableFiltersEnum.billingEntityCode:
      return value
    case AvailableFiltersEnum.externalId:
      return value
    default:
      return value
        .split(',')
        .map((v) => `${v.charAt(0).toUpperCase()}${v.slice(1).replace(/_/g, ' ')}`)
        .join(', ')
  }
}

type SecurityLogsQueryFilters = Partial<
  Pick<GetSecurityLogsQueryVariables, 'logEvents' | 'logTypes' | 'userIds' | 'fromDate' | 'toDate'>
>

export const formatFiltersForSecurityLogsQuery = (
  searchParams: URLSearchParams,
): SecurityLogsQueryFilters => {
  return formatFiltersForQuery<SecurityLogsQueryFilters>({
    searchParams: defineDefaultToDateValue(searchParams, SECURITY_LOGS_FILTER_PREFIX),
    availableFilters: SecurityLogsAvailableFilters,
    filtersNamePrefix: SECURITY_LOGS_FILTER_PREFIX,
  })
}

type QuotesQueryFilters = Partial<
  Pick<
    GetQuotesQueryVariables,
    'statuses' | 'customers' | 'numbers' | 'orderTypes' | 'owners' | 'fromDate' | 'toDate'
  >
>

export const formatFiltersForQuotesQuery = (searchParams: URLSearchParams): QuotesQueryFilters =>
  formatFiltersForQuery<QuotesQueryFilters>({
    searchParams,
    availableFilters: QuoteAvailableFilters,
    filtersNamePrefix: QUOTE_LIST_FILTER_PREFIX,
    keyMap: {
      [AvailableFiltersEnum.multipleCustomers]: 'customers',
      [AvailableFiltersEnum.quoteStatus]: 'statuses',
      [AvailableFiltersEnum.quoteNumber]: 'numbers',
      [AvailableFiltersEnum.quoteOrderType]: 'orderTypes',
      [AvailableFiltersEnum.userIds]: 'owners',
    },
  })

type OrderFormsQueryFilters = Partial<
  Pick<
    GetOrderFormsQueryVariables,
    'status' | 'number' | 'customerId' | 'ownerId' | 'createdAtFrom' | 'createdAtTo'
  >
>

export const formatFiltersForOrderFormsQuery = (
  searchParams: URLSearchParams,
): OrderFormsQueryFilters =>
  formatFiltersForQuery<OrderFormsQueryFilters>({
    searchParams,
    availableFilters: OrderFormAvailableFilters,
    filtersNamePrefix: ORDER_FORM_LIST_FILTER_PREFIX,
    keyMap: {
      [AvailableFiltersEnum.orderFormStatus]: 'status',
      [AvailableFiltersEnum.orderFormNumber]: 'number',
      [AvailableFiltersEnum.multipleCustomers]: 'customerId',
      [AvailableFiltersEnum.userIds]: 'ownerId',
    },
  })

type OrdersQueryFilters = Partial<
  Pick<
    GetOrdersQueryVariables,
    | 'status'
    | 'number'
    | 'customerId'
    | 'ownerId'
    | 'executionMode'
    | 'executedAtFrom'
    | 'executedAtTo'
  >
>

export const formatFiltersForOrdersQuery = (searchParams: URLSearchParams): OrdersQueryFilters =>
  formatFiltersForQuery<OrdersQueryFilters>({
    searchParams,
    availableFilters: OrderAvailableFilters,
    filtersNamePrefix: ORDER_LIST_FILTER_PREFIX,
    keyMap: {
      [AvailableFiltersEnum.orderStatus]: 'status',
      [AvailableFiltersEnum.orderNumber]: 'number',
      [AvailableFiltersEnum.multipleCustomers]: 'customerId',
      [AvailableFiltersEnum.orderExecutionMode]: 'executionMode',
      [AvailableFiltersEnum.userIds]: 'ownerId',
    },
  })

export const isOutstandingUrlParams = ({
  prefix,
  searchParams,
}: {
  searchParams: URLSearchParams
  prefix?: string
}): boolean => {
  return (
    searchParams.size >= 2 &&
    searchParams.get(keyWithPrefix('paymentStatus', prefix)) ===
      `${InvoicePaymentStatusTypeEnum.Failed},${InvoicePaymentStatusTypeEnum.Pending}` &&
    searchParams.get(keyWithPrefix('status', prefix)) === InvoiceStatusTypeEnum.Finalized
  )
}

export const isSucceededUrlParams = ({
  prefix,
  searchParams,
}: {
  searchParams: URLSearchParams
  prefix?: string
}): boolean => {
  return (
    searchParams.size >= 2 &&
    searchParams.get(keyWithPrefix('paymentStatus', prefix)) ===
      InvoicePaymentStatusTypeEnum.Succeeded &&
    searchParams.get(keyWithPrefix('status', prefix)) === InvoiceStatusTypeEnum.Finalized
  )
}

export const isDraftUrlParams = ({
  prefix,
  searchParams,
}: {
  searchParams: URLSearchParams
  prefix?: string
}): boolean => {
  return (
    searchParams.size >= 1 &&
    searchParams.get(keyWithPrefix('status', prefix)) === InvoiceStatusTypeEnum.Draft
  )
}

export const isPaymentOverdueUrlParams = ({
  prefix,
  searchParams,
}: {
  searchParams: URLSearchParams
  prefix?: string
}): boolean => {
  return (
    searchParams.size >= 1 && searchParams.get(keyWithPrefix('paymentOverdue', prefix)) === 'true'
  )
}

export const isVoidedUrlParams = ({
  prefix,
  searchParams,
}: {
  searchParams: URLSearchParams
  prefix?: string
}): boolean => {
  return (
    searchParams.size >= 1 &&
    searchParams.get(keyWithPrefix('status', prefix)) === InvoiceStatusTypeEnum.Voided
  )
}

export const isPaymentDisputeLostUrlParams = ({
  prefix,
  searchParams,
}: {
  searchParams: URLSearchParams
  prefix?: string
}): boolean => {
  return (
    searchParams.size >= 1 &&
    searchParams.get(keyWithPrefix('paymentDisputeLost', prefix)) === 'true'
  )
}

export const getFilterValue = ({
  key,
  searchParams,
  prefix,
}: {
  key: AvailableFiltersEnum
  searchParams: URLSearchParams
  prefix?: string
}): string | null => {
  return searchParams.get(keyWithPrefix(key, prefix))
}

export const setFilterValue = ({
  key,
  value,
  searchParams,
  prefix,
}: {
  key: AvailableFiltersEnum
  value: string
  searchParams: URLSearchParams
  prefix?: string
}): URLSearchParams => {
  searchParams.set(keyWithPrefix(key, prefix), value)
  return searchParams
}

export const buildUrlForInvoicesWithFilters = (searchParams: URLSearchParams) => {
  const searchParamsWithPrefix: Record<string, string> = {}

  searchParams.forEach((value, key) => {
    const prefix = keyWithPrefix(key, INVOICE_LIST_FILTER_PREFIX)

    searchParamsWithPrefix[prefix] = value
  })

  return `${INVOICES_ROUTE}?${new URLSearchParams(searchParamsWithPrefix).toString()}`
}
