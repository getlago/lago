// By convention, we use value then metadata (usually display value) on each side of the separator.
export const filterDataInlineSeparator = '|-_-|'

// Multiple-value filters join their selections with a comma. Display labels (customer/entity
// names, emails) embedded after the separator can themselves contain commas, which would
// over-split a single selection into several. Encode such commas with this placeholder and
// decode them back only for display — see escapeFilterLabel / unescapeFilterLabel in utils.
export const filterDataLabelCommaPlaceholder = '|-COMMA-|'

export enum AvailableQuickFilters {
  invoiceStatus = 'invoiceStatus',
  customerAccountType = 'customerAccountType',
  timeGranularity = 'timeGranularity',
  unitsAmount = 'unitsAmount',
}

export enum AmountFilterInterval {
  isBetween = 'isBetween',
  isEqualTo = 'isEqualTo',
  isUpTo = 'isUpTo',
  isAtLeast = 'isAtLeast',
}

export enum ActiveSubscriptionsFilterInterval {
  isBetween = 'isBetween',
  isEqualTo = 'isEqualTo',
  isGreaterThan = 'isGreaterThan',
  isLessThan = 'isLessThan',
}

export const AMOUNT_INTERVALS_TRANSLATION_MAP: Record<AmountFilterInterval, string> = {
  [AmountFilterInterval.isBetween]: 'text_1734774653389kvylgxjiltu',
  [AmountFilterInterval.isEqualTo]: 'text_1734774653389pt3rhh3lspa',
  [AmountFilterInterval.isUpTo]: 'text_1734792781750cot2uyp6f1x',
  [AmountFilterInterval.isAtLeast]: 'text_17347927817503hromltntvm',
}

export const ACTIVE_SUBSCRIPTIONS_INTERVALS_TRANSLATION_MAP: Record<
  ActiveSubscriptionsFilterInterval,
  string
> = {
  [ActiveSubscriptionsFilterInterval.isBetween]: 'text_1734774653389kvylgxjiltu',
  [ActiveSubscriptionsFilterInterval.isEqualTo]: 'text_1734774653389pt3rhh3lspa',
  [ActiveSubscriptionsFilterInterval.isGreaterThan]: 'text_1754397427626s7wx2frw0f4',
  [ActiveSubscriptionsFilterInterval.isLessThan]: 'text_1754397427626jjvqhvplifr',
}

export enum AvailableFiltersEnum {
  activityIds = 'activityIds',
  activitySources = 'activitySources',
  activityTypes = 'activityTypes',
  activeSubscriptions = 'activeSubscriptions',
  amount = 'amount',
  apiKeyIds = 'apiKeyIds',
  billableMetricCode = 'billableMetricCode',
  billingEntityIds = 'billingEntityIds',
  billingEntityId = 'billingEntityId',
  billingEntityCode = 'billingEntityCode',
  country = 'country',
  countries = 'countries',
  creditNoteCreditStatus = 'creditNoteCreditStatus',
  creditNoteReason = 'creditNoteReason',
  creditNoteRefundStatus = 'creditNoteRefundStatus',
  creditNoteType = 'creditNoteType',
  currency = 'currency',
  currencies = 'currencies',
  customerType = 'customerType',
  customerAccountType = 'accountType',
  customerExternalId = 'customerExternalId',
  externalId = 'externalId',
  isCustomerTinEmpty = 'isCustomerTinEmpty',
  date = 'date',
  hasCustomerType = 'hasCustomerType',
  httpMethods = 'httpMethods',
  httpStatuses = 'httpStatuses',
  invoiceNumber = 'invoiceNumber',
  invoiceType = 'invoiceType',
  issuingDate = 'issuingDate',
  loggedDate = 'loggedDate',
  logEvents = 'logEvents',
  logTypes = 'logTypes',
  metadata = 'metadata',
  multipleCustomers = 'multipleCustomers',
  overriden = 'overriden',
  partiallyPaid = 'partiallyPaid',
  paymentDisputeLost = 'paymentDisputeLost',
  paymentOverdue = 'paymentOverdue',
  paymentStatus = 'paymentStatus',
  planCode = 'planCode',
  orderFormCreatedAt = 'orderFormCreatedAt',
  orderFormNumber = 'orderFormNumber',
  orderFormStatus = 'orderFormStatus',
  orderStatus = 'orderStatus',
  orderNumber = 'orderNumber',
  orderExecutedAt = 'orderExecutedAt',
  orderExecutionMode = 'orderExecutionMode',
  quoteCreatedAt = 'quoteCreatedAt',
  quoteNumber = 'quoteNumber',
  quoteOrderType = 'quoteOrderType',
  quoteStatus = 'quoteStatus',
  requestPaths = 'requestPaths',
  resourceIds = 'resourceIds',
  resourceTypes = 'resourceTypes',
  selfBilled = 'selfBilled',
  settlementType = 'settlementType',
  states = 'states',
  status = 'status',
  subscriptionStatus = 'subscriptionStatus',
  subscriptionExternalId = 'subscriptionExternalId',
  timeGranularity = 'timeGranularity',
  period = 'period',
  userEmails = 'userEmails',
  webhookDate = 'webhookDate',
  webhookEventTypes = 'webhookEventTypes',
  webhookHttpStatuses = 'webhookHttpStatuses',
  userIds = 'userIds',
  webhookStatus = 'webhookStatus',
  zipcodes = 'zipcodes',
}

export const CreditNoteAvailableFilters = [
  AvailableFiltersEnum.amount,
  AvailableFiltersEnum.creditNoteCreditStatus,
  AvailableFiltersEnum.creditNoteType,
  AvailableFiltersEnum.currency,
  AvailableFiltersEnum.customerExternalId,
  AvailableFiltersEnum.invoiceNumber,
  AvailableFiltersEnum.issuingDate,
  AvailableFiltersEnum.creditNoteReason,
  AvailableFiltersEnum.creditNoteRefundStatus,
  AvailableFiltersEnum.selfBilled,
  AvailableFiltersEnum.billingEntityIds,
]

export const InvoiceAvailableFilters = [
  AvailableFiltersEnum.currency,
  AvailableFiltersEnum.customerExternalId,
  AvailableFiltersEnum.invoiceType,
  AvailableFiltersEnum.issuingDate,
  AvailableFiltersEnum.partiallyPaid,
  AvailableFiltersEnum.paymentDisputeLost,
  AvailableFiltersEnum.paymentOverdue,
  AvailableFiltersEnum.paymentStatus,
  AvailableFiltersEnum.settlementType,
  AvailableFiltersEnum.status,
  AvailableFiltersEnum.amount,
  AvailableFiltersEnum.selfBilled,
  AvailableFiltersEnum.billingEntityIds,
]

export const RevenueStreamsAvailablePopperFilters = [
  AvailableFiltersEnum.date,
  AvailableFiltersEnum.country,
  AvailableFiltersEnum.currency,
  AvailableFiltersEnum.customerType,
  AvailableFiltersEnum.customerExternalId,
  AvailableFiltersEnum.planCode,
  AvailableFiltersEnum.subscriptionExternalId,
  AvailableFiltersEnum.billingEntityCode,
  AvailableFiltersEnum.isCustomerTinEmpty,
]

export const CustomerAvailableFilters = [
  AvailableFiltersEnum.customerAccountType,
  AvailableFiltersEnum.billingEntityIds,
  AvailableFiltersEnum.activeSubscriptions,
  AvailableFiltersEnum.customerType,
  AvailableFiltersEnum.countries,
  AvailableFiltersEnum.currencies,
  AvailableFiltersEnum.externalId,
  AvailableFiltersEnum.states,
  AvailableFiltersEnum.zipcodes,
  AvailableFiltersEnum.isCustomerTinEmpty,
  AvailableFiltersEnum.hasCustomerType,
  AvailableFiltersEnum.metadata,
]

export const RevenueStreamsPlansAvailableFilters = [AvailableFiltersEnum.currency]
export const RevenueStreamsCustomersAvailableFilters = [AvailableFiltersEnum.currency]
export const MrrOverviewAvailableFilters = [
  AvailableFiltersEnum.date,
  AvailableFiltersEnum.country,
  AvailableFiltersEnum.currency,
  AvailableFiltersEnum.customerType,
  AvailableFiltersEnum.customerExternalId,
  AvailableFiltersEnum.billingEntityCode,
  AvailableFiltersEnum.isCustomerTinEmpty,
]
export const MrrBreakdownPlansAvailableFilters = [AvailableFiltersEnum.currency]
export const PrepaidCreditsOverviewAvailableFilters = [
  AvailableFiltersEnum.date,
  AvailableFiltersEnum.country,
  AvailableFiltersEnum.currency,
  AvailableFiltersEnum.customerAccountType,
  AvailableFiltersEnum.customerExternalId,
  AvailableFiltersEnum.billingEntityCode,
  AvailableFiltersEnum.isCustomerTinEmpty,
]

export const AnalyticsInvoicesAvailableFilters = [
  AvailableFiltersEnum.currency,
  AvailableFiltersEnum.period,
  AvailableFiltersEnum.billingEntityCode,
  AvailableFiltersEnum.isCustomerTinEmpty,
]

export const WebhookLogsAvailableFilters = [
  AvailableFiltersEnum.webhookDate,
  AvailableFiltersEnum.webhookStatus,
  AvailableFiltersEnum.webhookEventTypes,
  AvailableFiltersEnum.webhookHttpStatuses,
]

export const UsageOverviewAvailableFilters = [
  AvailableFiltersEnum.date,
  AvailableFiltersEnum.country,
  AvailableFiltersEnum.currency,
  AvailableFiltersEnum.customerAccountType,
  AvailableFiltersEnum.customerExternalId,
  AvailableFiltersEnum.planCode,
  AvailableFiltersEnum.subscriptionExternalId,
  AvailableFiltersEnum.billingEntityCode,
  AvailableFiltersEnum.isCustomerTinEmpty,
]

export const UsageBreakdownAvailableFilters = [
  AvailableFiltersEnum.date,
  AvailableFiltersEnum.country,
  AvailableFiltersEnum.currency,
  AvailableFiltersEnum.customerAccountType,
  AvailableFiltersEnum.customerExternalId,
  AvailableFiltersEnum.planCode,
  AvailableFiltersEnum.subscriptionExternalId,
]

export const UsageBreakdownMeteredAvailableFilters = [
  AvailableFiltersEnum.date,
  AvailableFiltersEnum.country,
  AvailableFiltersEnum.currency,
  AvailableFiltersEnum.customerAccountType,
  AvailableFiltersEnum.customerExternalId,
  AvailableFiltersEnum.planCode,
  AvailableFiltersEnum.subscriptionExternalId,
]

export const UsageBreakdownRecurringAvailableFilters = [
  AvailableFiltersEnum.date,
  AvailableFiltersEnum.country,
  AvailableFiltersEnum.currency,
  AvailableFiltersEnum.customerAccountType,
  AvailableFiltersEnum.customerExternalId,
  AvailableFiltersEnum.planCode,
  AvailableFiltersEnum.subscriptionExternalId,
]

export const UsageBillableMetricAvailableFilters = [
  AvailableFiltersEnum.date,
  AvailableFiltersEnum.country,
  AvailableFiltersEnum.currency,
  AvailableFiltersEnum.customerAccountType,
  AvailableFiltersEnum.customerExternalId,
  AvailableFiltersEnum.planCode,
  AvailableFiltersEnum.subscriptionExternalId,
]

export const ForecastsAvailableFilters = [
  AvailableFiltersEnum.billableMetricCode,
  AvailableFiltersEnum.billingEntityCode,
  AvailableFiltersEnum.country,
  AvailableFiltersEnum.currency,
  AvailableFiltersEnum.customerExternalId,
  AvailableFiltersEnum.customerAccountType,
  AvailableFiltersEnum.isCustomerTinEmpty,
  AvailableFiltersEnum.planCode,
  AvailableFiltersEnum.subscriptionExternalId,
]

export const ActivityLogsAvailableFilters = [
  AvailableFiltersEnum.loggedDate,
  AvailableFiltersEnum.apiKeyIds,
  AvailableFiltersEnum.activityIds,
  AvailableFiltersEnum.resourceTypes,
  AvailableFiltersEnum.resourceIds,
  AvailableFiltersEnum.activityTypes,
  AvailableFiltersEnum.activitySources,
  AvailableFiltersEnum.customerExternalId,
  AvailableFiltersEnum.subscriptionExternalId,
  AvailableFiltersEnum.userEmails,
]

export const ApiLogsAvailableFilters = [
  AvailableFiltersEnum.loggedDate,
  AvailableFiltersEnum.apiKeyIds,
  AvailableFiltersEnum.requestPaths,
  AvailableFiltersEnum.httpMethods,
  AvailableFiltersEnum.httpStatuses,
]

export const SubscriptionAvailableFilters = [
  AvailableFiltersEnum.billingEntityIds,
  AvailableFiltersEnum.customerExternalId,
  AvailableFiltersEnum.externalId,
  AvailableFiltersEnum.overriden,
  AvailableFiltersEnum.planCode,
  AvailableFiltersEnum.subscriptionStatus,
]

export const CustomerAnalyticsAvailableFilters = [
  AvailableFiltersEnum.currency,
  AvailableFiltersEnum.billingEntityId,
]

export const CustomerInvoicesAvailableFilters = [
  AvailableFiltersEnum.currency,
  AvailableFiltersEnum.billingEntityId,
]

export const CustomerPaymentsAvailableFilters = [AvailableFiltersEnum.currency]

export const CustomerCreditNotesAvailableFilters = [
  AvailableFiltersEnum.currency,
  AvailableFiltersEnum.billingEntityId,
]

export const SecurityLogsAvailableFilters = [
  AvailableFiltersEnum.loggedDate,
  AvailableFiltersEnum.logEvents,
  AvailableFiltersEnum.logTypes,
  AvailableFiltersEnum.userIds,
]

export const QuoteAvailableFilters = [
  AvailableFiltersEnum.quoteStatus,
  AvailableFiltersEnum.multipleCustomers,
  AvailableFiltersEnum.quoteNumber,
  AvailableFiltersEnum.quoteCreatedAt,
  AvailableFiltersEnum.quoteOrderType,
  AvailableFiltersEnum.userIds,
]

export const OrderFormAvailableFilters = [
  AvailableFiltersEnum.orderFormStatus,
  AvailableFiltersEnum.multipleCustomers,
  AvailableFiltersEnum.orderFormNumber,
  AvailableFiltersEnum.orderFormCreatedAt,
  AvailableFiltersEnum.userIds,
]

export const OrderAvailableFilters = [
  AvailableFiltersEnum.orderStatus,
  AvailableFiltersEnum.multipleCustomers,
  AvailableFiltersEnum.orderNumber,
  AvailableFiltersEnum.orderExecutedAt,
  AvailableFiltersEnum.orderExecutionMode,
  AvailableFiltersEnum.userIds,
]

const translationMap: Record<AvailableFiltersEnum, string> = {
  [AvailableFiltersEnum.activityIds]: 'text_1747666154075d10admbnf16',
  [AvailableFiltersEnum.activitySources]: 'text_1747666154075g4ceq9ii0xm',
  [AvailableFiltersEnum.activityTypes]: 'text_1747666154075d7ame7sqkxa',
  [AvailableFiltersEnum.activeSubscriptions]: 'text_65281f686a80b400c8e2f6be',
  [AvailableFiltersEnum.amount]: 'text_17346988752182hpzppdqk9t',
  [AvailableFiltersEnum.apiKeyIds]: 'text_645d071272418a14c1c76aa4',
  [AvailableFiltersEnum.billableMetricCode]: 'text_1761553933730mc7ttuol4be',
  [AvailableFiltersEnum.billingEntityIds]: 'text_17436114971570doqrwuwhf0',
  [AvailableFiltersEnum.billingEntityId]: 'text_17791856837133nbboq5tcxi',
  [AvailableFiltersEnum.billingEntityCode]: 'text_1747986368158jgf5jdvfsey',
  [AvailableFiltersEnum.country]: 'text_62ab2d0396dd6b0361614da0',
  [AvailableFiltersEnum.countries]: 'text_17599097360429zjcfmkb9oi',
  [AvailableFiltersEnum.creditNoteCreditStatus]: 'text_173470389114473bzrbyh6va',
  [AvailableFiltersEnum.creditNoteReason]: 'text_1734703891144ptrs5sty2bg',
  [AvailableFiltersEnum.creditNoteRefundStatus]: 'text_1734703891144vv5iclhl4vz',
  [AvailableFiltersEnum.creditNoteType]: 'text_632d68358f1fedc68eed3e5a',
  [AvailableFiltersEnum.currency]: 'text_632b4acf0c41206cbcb8c324',
  [AvailableFiltersEnum.currencies]: 'text_1759909828496b1rzn43dtvt',
  [AvailableFiltersEnum.customerType]: 'text_1726128938631ioz4orixel3',
  [AvailableFiltersEnum.customerAccountType]: 'text_1744108096469xz5cnvtoixf',
  [AvailableFiltersEnum.customerExternalId]: 'text_65201c5a175a4b0238abf29a',
  [AvailableFiltersEnum.externalId]: 'text_6250304370f0f700a8fdc283',
  [AvailableFiltersEnum.isCustomerTinEmpty]: 'text_1751629285990kftdtjbv2dc',
  [AvailableFiltersEnum.date]: 'text_664cb90097bfa800e6efa3f5',
  [AvailableFiltersEnum.hasCustomerType]: 'text_1759932717174x6ajk3qawwl',
  [AvailableFiltersEnum.httpMethods]: 'text_1749819999031vobdu7h2c7c',
  [AvailableFiltersEnum.httpStatuses]: 'text_63ac86d797f728a87b2f9fa7',
  [AvailableFiltersEnum.invoiceNumber]: 'text_1734698875218fbxzci2g2s2',
  [AvailableFiltersEnum.invoiceType]: 'text_632d68358f1fedc68eed3e5a',
  [AvailableFiltersEnum.issuingDate]: 'text_6419c64eace749372fc72b39',
  [AvailableFiltersEnum.loggedDate]: 'text_1747666154074cdsfaq5c4bz',
  [AvailableFiltersEnum.logEvents]: 'text_1772026899880ogvwyuadgu7',
  [AvailableFiltersEnum.logTypes]: 'text_1772026899880bb07acdof6w',
  [AvailableFiltersEnum.metadata]: 'text_63fcc3218d35b9377840f59b',
  [AvailableFiltersEnum.multipleCustomers]: 'text_65201c5a175a4b0238abf29a',
  [AvailableFiltersEnum.overriden]: 'text_65281f686a80b400c8e2f6dd',
  [AvailableFiltersEnum.partiallyPaid]: 'text_1738071221799vib0l2z1bxe',
  [AvailableFiltersEnum.paymentDisputeLost]: 'text_66141e30699a0631f0b2ed32',
  [AvailableFiltersEnum.paymentOverdue]: 'text_666c5b12fea4aa1e1b26bf55',
  [AvailableFiltersEnum.paymentStatus]: 'text_63eba8c65a6c8043feee2a0f',
  [AvailableFiltersEnum.planCode]: 'text_642d5eb2783a2ad10d670320',
  [AvailableFiltersEnum.orderFormCreatedAt]: 'text_1776870266380s3zbpmnfrhj',
  [AvailableFiltersEnum.orderFormNumber]: 'text_1781624189693d7zcv2vog4c',
  [AvailableFiltersEnum.orderFormStatus]: 'text_63ac86d797f728a87b2f9fa7',
  [AvailableFiltersEnum.orderStatus]: 'text_63ac86d797f728a87b2f9fa7',
  [AvailableFiltersEnum.orderNumber]: 'text_1782392058759pmmuy0h997w',
  [AvailableFiltersEnum.orderExecutedAt]: 'text_1782489945765vho6glo5dtv',
  [AvailableFiltersEnum.orderExecutionMode]: 'text_17823920587599ha9n3uhfuj',
  [AvailableFiltersEnum.quoteCreatedAt]: 'text_1776870266380s3zbpmnfrhj',
  [AvailableFiltersEnum.quoteNumber]: 'text_1776870266380lnc721e4opb',
  [AvailableFiltersEnum.quoteOrderType]: 'text_1776870266380ydi5pjfjcqq',
  [AvailableFiltersEnum.quoteStatus]: 'text_63ac86d797f728a87b2f9fa7',
  [AvailableFiltersEnum.requestPaths]: 'text_1749819999030uz8ddys1puu',
  [AvailableFiltersEnum.resourceIds]: 'text_1747666154075y3lcupj1zdd',
  [AvailableFiltersEnum.resourceTypes]: 'text_1732895022171f9vnwh5gm3q',
  [AvailableFiltersEnum.selfBilled]: 'text_1738595318403vcyh77pwiew',
  [AvailableFiltersEnum.settlementType]: 'text_1769621581645i96s4n9hbnw',
  [AvailableFiltersEnum.states]: 'text_1759909828496nk6yvooqbb5',
  [AvailableFiltersEnum.status]: 'text_63ac86d797f728a87b2f9fa7',
  [AvailableFiltersEnum.subscriptionExternalId]: 'text_1741008626283x4p1zwj11zi',
  [AvailableFiltersEnum.subscriptionStatus]: 'text_63ac86d797f728a87b2f9fa7',
  [AvailableFiltersEnum.timeGranularity]: '', // Used in quick filters only
  [AvailableFiltersEnum.period]: 'text_1746532851931rt2nl6vdlnh',
  [AvailableFiltersEnum.userEmails]: 'text_1747666154075t42hri31gvz',
  [AvailableFiltersEnum.webhookDate]: 'text_1771575899591jxhprdv5fuh',
  [AvailableFiltersEnum.webhookEventTypes]: 'text_1771575899591p8b9e7wu4nh',
  [AvailableFiltersEnum.webhookHttpStatuses]: 'text_1771575108779ayv0gbdcjfr',
  [AvailableFiltersEnum.userIds]: 'text_1772026899880swtnqcqd6s3',
  [AvailableFiltersEnum.webhookStatus]: 'text_63ac86d797f728a87b2f9fa7',
  [AvailableFiltersEnum.zipcodes]: 'text_1759909828496sof33smekse',
}

export type FiltersFormValues = {
  filters: Array<{
    filterType?: AvailableFiltersEnum
    value?: string
    disabled?: boolean
  }>
}

export const mapFilterToTranslationKey = (filter: AvailableFiltersEnum) => {
  return translationMap[filter] || filter
}
