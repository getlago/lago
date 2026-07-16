import { ApolloError, ApolloQueryResult, gql } from '@apollo/client'
import { Icon } from 'lago-design-system'
import { Fragment, useEffect, useRef, useState } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import {
  SubscriptionUsageDetailDrawer,
  SubscriptionUsageDetailDrawerRef,
  SubscriptionUsageDetailDrawerUsage,
} from '~/components/customers/usage/SubscriptionUsageDetailDrawer'
import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { NavigationTab, TabManagedBy } from '~/components/designSystem/NavigationTab'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Table } from '~/components/designSystem/Table/Table'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography, TypographyColor } from '~/components/designSystem/Typography'
import { findChargeUsageByBillableMetricId } from '~/components/subscriptions/utils'
import { addToast, hasDefinedGQLError, LagoGQLError } from '~/core/apolloClient'
import { LocalTaxProviderErrorsEnum } from '~/core/constants/form'
import { CustomerSubscriptionDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import {
  CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE,
  PLAN_SUBSCRIPTION_DETAILS_ROUTE,
  useNavigate,
} from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { intlFormatDateTime } from '~/core/timezone'
import { LocaleEnum } from '~/core/translations'
import {
  CurrencyEnum,
  CustomerForSubscriptionUsageQuery,
  CustomerProjectedUsageForUsageDetailsFragmentDoc,
  CustomerUsageForUsageDetailsFragmentDoc,
  GetCustomerProjectedUsageForPortalQuery,
  GetCustomerUsageForPortalQuery,
  LagoApiError,
  PremiumIntegrationTypeEnum,
  ProjectedUsageForSubscriptionUsageQuery,
  StatusTypeEnum,
  SubscrptionForSubscriptionUsageQuery,
  TimezoneEnum,
  UsageForSubscriptionUsageQuery,
  useCustomerForSubscriptionUsageQuery,
  useProjectedUsageForSubscriptionUsageQuery,
  useSubscrptionForSubscriptionUsageQuery,
  useUsageForSubscriptionUsageQuery,
} from '~/generated/graphql'
import { TranslateFunc, useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import EmptyImage from '~/public/images/maneki/empty.svg'
import ErrorImage from '~/public/images/maneki/error.svg'

import { usePremiumWarningDialog } from '../dialogs/PremiumWarningDialog'

gql`
  query customerForSubscriptionUsage($customerId: ID!) {
    customer(id: $customerId) {
      id
      applicableTimezone
    }
  }

  query subscrptionForSubscriptionUsage($subscription: ID!) {
    subscription(id: $subscription) {
      id
      name
      status
      plan {
        id
        name
        code
      }
      customer {
        id
        applicableTimezone
      }
    }
  }

  fragment SubscriptionCurrentUsageTableComponentCustomerUsage on CustomerUsage {
    amountCents
    currency
    fromDatetime
    toDatetime
    chargesUsage {
      id
      units
      amountCents
      pricingUnitAmountCents
      charge {
        id
        invoiceDisplayName
        appliedPricingUnit {
          id
          pricingUnit {
            id
            shortName
          }
        }
        properties {
          pricingGroupKeys
          presentationGroupKeys {
            value
          }
        }
      }
      billableMetric {
        id
        code
        name
      }
      filters {
        id
        invoiceDisplayName
      }
      groupedUsage {
        amountCents
        groupedBy
        eventsCount
        units
        filters {
          id
        }
      }
    }
  }

  fragment SubscriptionCurrentUsageTableComponentCustomerProjectedUsage on CustomerProjectedUsage {
    amountCents
    projectedAmountCents
    currency
    fromDatetime
    toDatetime
    chargesUsage {
      id
      units
      amountCents
      pricingUnitAmountCents
      projectedUnits
      projectedAmountCents
      pricingUnitProjectedAmountCents
      charge {
        id
        invoiceDisplayName
        appliedPricingUnit {
          id
          pricingUnit {
            id
            shortName
          }
        }
        properties {
          pricingGroupKeys
          presentationGroupKeys {
            value
          }
        }
      }
      billableMetric {
        id
        code
        name
      }
      filters {
        id
        invoiceDisplayName
      }
      groupedUsage {
        amountCents
        groupedBy
        eventsCount
        units
        projectedUnits
        projectedAmountCents
        filters {
          id
        }
      }
    }
  }

  query usageForSubscriptionUsage($customerId: ID!, $subscriptionId: ID!) {
    customerUsage(customerId: $customerId, subscriptionId: $subscriptionId) {
      amountCents
      ...SubscriptionCurrentUsageTableComponentCustomerUsage
      ...CustomerUsageForUsageDetails
    }
  }

  query projectedUsageForSubscriptionUsage($customerId: ID!, $subscriptionId: ID!) {
    customerProjectedUsage(customerId: $customerId, subscriptionId: $subscriptionId) {
      amountCents
      projectedAmountCents
      ...SubscriptionCurrentUsageTableComponentCustomerProjectedUsage
      ...CustomerProjectedUsageForUsageDetails
    }
  }

  ${CustomerUsageForUsageDetailsFragmentDoc}
  ${CustomerProjectedUsageForUsageDetailsFragmentDoc}
`

interface SubscriptionCurrentUsageTableProps {
  customerId: string
  subscriptionId: string
}

export type UsageData = UsageForSubscriptionUsageQuery['customerUsage'] &
  ProjectedUsageForSubscriptionUsageQuery['customerProjectedUsage'] &
  GetCustomerUsageForPortalQuery['customerPortalCustomerUsage'] &
  GetCustomerProjectedUsageForPortalQuery['customerPortalCustomerProjectedUsage']

type SubscriptionCurrentUsageTableComponentProps = {
  usageData?: UsageData
  usageLoading: boolean
  usageError?: ApolloError

  subscription?: SubscrptionForSubscriptionUsageQuery['subscription']
  subscriptionLoading: boolean

  subscriptionError?: ApolloError

  customerData?: CustomerForSubscriptionUsageQuery['customer']
  customerLoading: boolean
  customerError?: ApolloError

  refetchUsage: (
    forceProjected?: boolean,
  ) => Promise<
    ApolloQueryResult<
      | UsageForSubscriptionUsageQuery
      | ProjectedUsageForSubscriptionUsageQuery
      | GetCustomerUsageForPortalQuery
      | GetCustomerProjectedUsageForPortalQuery
    >
  >

  noUsageOverride?: React.ReactNode

  translate: TranslateFunc
  locale?: LocaleEnum

  activeTab: number
  setActiveTab: (t: number) => void

  hasAccessToProjectedUsage?: boolean
  isUsedinCustomerPortal?: boolean
}

export const getPricingUnitAmountCents = (
  row: {
    amountCents?: string | number
    pricingUnitAmountCents?: string | number
    pricingUnitProjectedAmountCents?: string | number
    projectedAmountCents?: string | number
  },
  isProjected?: boolean,
) => {
  return isProjected
    ? row.pricingUnitProjectedAmountCents || row.projectedAmountCents
    : row.pricingUnitAmountCents || row.amountCents
}

export type MixedCharge = {
  projectedAmountCents?: string | number
  amountCents?: string | number
  projectedUnits?: string | number
  units?: string | number
}

type UsageSummaryPanelProps = {
  usageData?: UsageData
  currency: CurrencyEnum
  isLoading: boolean
  hasError: boolean
  translate: TranslateFunc
  locale?: LocaleEnum
  getFormattedDate: (date: string) => string
  showProjectedColumn: boolean
}

const UsageSummaryPanel = ({
  usageData,
  currency,
  isLoading,
  hasError,
  translate,
  locale,
  getFormattedDate,
  showProjectedColumn,
}: UsageSummaryPanelProps) => {
  const currencyDisplay = locale ? 'narrowSymbol' : 'symbol'

  const formatAmount = (cents: string | number | null | undefined): string =>
    intlFormatNumber(deserializeAmount(cents || 0, currency) || 0, {
      currencyDisplay,
      currency,
      locale,
    })

  const renderValue = (value: string, textColor: TypographyColor = 'grey700') =>
    isLoading ? (
      <Skeleton variant="text" className="mt-1 w-36" />
    ) : (
      <Typography variant="bodyHl" color={textColor} noWrap>
        {value}
      </Typography>
    )

  const dateRange =
    !hasError && !!usageData?.fromDatetime && !!usageData?.toDatetime
      ? `${getFormattedDate(usageData.fromDatetime)} - ${getFormattedDate(usageData.toDatetime)}`
      : '-'

  return (
    <div className="w-full shadow-b">
      <div className="flex w-fit items-stretch divide-x divide-grey-300 py-4">
        <div className="flex flex-col gap-1 px-8 first:pl-0">
          <Typography variant="captionHl" color="grey600" noWrap>
            {translate('text_1778841363033djjc5c8dsvx')}
          </Typography>
          {renderValue(dateRange)}
        </div>

        <div className="flex flex-col gap-1 px-8">
          <Typography variant="captionHl" color="grey600" noWrap>
            {translate('text_17788413630335ar3zl10prt')}
          </Typography>
          {renderValue(formatAmount(usageData?.amountCents))}
        </div>

        {showProjectedColumn && (
          <div className="flex flex-col gap-1 px-8">
            <Typography variant="captionHl" color="grey600" noWrap>
              {translate('text_17788413630339w2go4tbxga')}
            </Typography>
            {renderValue(formatAmount(usageData?.projectedAmountCents), 'grey600')}
          </div>
        )}
      </div>
    </div>
  )
}

export const SubscriptionCurrentUsageTableComponent = ({
  usageData,
  usageLoading,
  usageError,
  subscription,
  subscriptionLoading,
  subscriptionError,
  customerData,
  customerLoading,
  customerError,
  refetchUsage,
  noUsageOverride,
  translate,
  locale,
  activeTab,
  setActiveTab,
  isUsedinCustomerPortal,
  hasAccessToProjectedUsage,
}: SubscriptionCurrentUsageTableComponentProps) => {
  const premiumWarningDialog = usePremiumWarningDialog()

  const subscriptionUsageDetailDrawerRef = useRef<SubscriptionUsageDetailDrawerRef>(null)

  const currency = usageData?.currency || CurrencyEnum.Usd
  const isLoading = subscriptionLoading || usageLoading || customerLoading
  const hasError = !!subscriptionError || !!usageError || !!customerError
  const customerTimezone =
    customerData?.applicableTimezone ||
    subscription?.customer.applicableTimezone ||
    TimezoneEnum.TzUtc

  const showProjected = activeTab === 1

  const handleOpenUsageDetailDrawer = (row: SubscriptionUsageDetailDrawerUsage) => {
    subscriptionUsageDetailDrawerRef.current?.openDrawer(
      row,
      async (forceProjected?: boolean) => {
        const { data } = await refetchUsage(forceProjected)

        return findChargeUsageByBillableMetricId(data, row.billableMetric.id)
      },
      activeTab,
    )
  }

  const TRANSLATION_MAP = showProjected
    ? {
        unitsHeader: translate('text_17531019276915hby502cvzy'),
        amountHeader: translate('text_1753101927691j5chrkhmoma'),
        emptyUsage:
          subscription?.status === StatusTypeEnum.Pending
            ? translate('text_1754662684478jvakvxllwie')
            : translate('text_1754662542899l1ms7k49n67'),
      }
    : {
        unitsHeader: translate('text_1753095789277t9kbe8y5pmh'),
        amountHeader: translate('text_1753101927691fbbwyk7p39q'),
        emptyUsage:
          subscription?.status === StatusTypeEnum.Pending
            ? translate('text_173142196943714qsq737sre')
            : translate('text_62c3f454e5d7f4ec8888c1d7'),
      }

  const amountCentsKey = showProjected ? 'projectedAmountCents' : 'amountCents'
  const unitsKey = showProjected ? 'projectedUnits' : 'units'
  const showPremiumError = showProjected && !hasAccessToProjectedUsage

  const getFormattedDate = (date: string): string => {
    return intlFormatDateTime(date, {
      timezone: customerTimezone,
      locale,
    }).date
  }

  return (
    <section>
      <div className="flex flex-row items-center justify-between">
        <div className="flex flex-col gap-1">
          <Typography variant="subhead1" color="grey700" noWrap>
            {translate('text_1725983967306cf8dwr2r4u2')}
          </Typography>
          <Typography variant="caption" color="grey600">
            {translate('text_1778496527600gzfmf3x6r2q')}
          </Typography>
        </div>
        <Tooltip placement="top-end" title={translate('text_62d7f6178ec94cd09370e4b3')}>
          <Button
            variant="inline"
            size="small"
            disabled={usageLoading}
            onClick={async () => {
              refetchUsage()
            }}
          >
            {translate('text_1738748043939zqoqzz350yj')}
          </Button>
        </Tooltip>
      </div>

      <UsageSummaryPanel
        usageData={usageData}
        currency={currency}
        isLoading={isLoading}
        hasError={hasError}
        translate={translate}
        locale={locale}
        getFormattedDate={getFormattedDate}
        showProjectedColumn={!!hasAccessToProjectedUsage}
      />

      <NavigationTab
        managedBy={TabManagedBy.INDEX}
        onChange={(index) => setActiveTab(index)}
        tabs={[
          {
            title: translate('text_1753094834414fgnvuior3iv'),
          },
          {
            title: translate('text_1753094834414tu9mxavuco7'),
            hidden: isUsedinCustomerPortal && !hasAccessToProjectedUsage,
          },
        ]}
      />

      {!!hasError && !isLoading && (
        <>
          {(usageError?.graphQLErrors?.length || 0) > 0 &&
          usageError?.graphQLErrors.find((graphQLError) => {
            const { extensions } = graphQLError as LagoGQLError

            return extensions?.details?.taxError?.length
          }) ? (
            <Alert fullWidth type="warning" className="shadow-t">
              <div>
                <Typography variant="body" color="grey700">
                  {translate('text_1724165657161stcilcabm7x')}
                </Typography>

                <Typography variant="caption">
                  {translate(LocalTaxProviderErrorsEnum.GenericErrorMessage)}
                </Typography>
              </div>
            </Alert>
          ) : (
            <GenericPlaceholder
              title={translate('text_62c3f3fca8a1625624e83379')}
              subtitle={translate('text_1726498444629i1fpjyvh0kg')}
              buttonTitle={translate('text_1725983967306qz0npfuhlo1')}
              buttonVariant="primary"
              buttonAction={() => refetchUsage()}
              image={<ErrorImage width="136" height="104" />}
            />
          )}
        </>
      )}

      {!hasError && !isLoading && !usageData?.chargesUsage.length && (
        <>
          {noUsageOverride ? (
            noUsageOverride
          ) : (
            <GenericPlaceholder
              title={translate('text_62c3f454e5d7f4ec8888c1d5')}
              subtitle={TRANSLATION_MAP.emptyUsage}
              image={<EmptyImage width="136" height="104" />}
            />
          )}
        </>
      )}

      {!hasError && !!usageData?.chargesUsage.length && showPremiumError && (
        <div className="mt-6 flex w-full flex-row items-center justify-between gap-2 rounded-xl bg-grey-100 px-6 py-4">
          <div className="flex flex-col">
            <div className="flex flex-row items-center gap-2">
              <Typography variant="bodyHl" color="grey700">
                {translate('text_1755599398258j905gj9xihx')}
              </Typography>
              <Icon name="sparkles" />
            </div>

            <Typography variant="caption" color="grey600">
              {translate('text_1755599398258ce1ilgc5swg')}
            </Typography>
          </div>

          <Button
            endIcon="sparkles"
            variant="tertiary"
            onClick={() =>
              premiumWarningDialog.open({
                title: translate('text_661ff6e56ef7e1b7c542b1ea'),
                description: translate('text_661ff6e56ef7e1b7c542b1f6'),
                mailtoSubject: translate('text_1755599398258mj61iwjhhfk'),
                mailtoBody: translate('text_1755599398258w59pin31rfe'),
              })
            }
          >
            {translate('text_65ae73ebe3a66bec2b91d72d')}
          </Button>
        </div>
      )}

      {!hasError &&
        !showPremiumError &&
        // Render the Table during loading too so its `isLoading` skeleton
        // shows on the Current/Projected tabs. Previously the cell was gated
        // on `chargesUsage.length`, which skipped the loading state entirely.
        (isLoading || !!usageData?.chargesUsage.length) && (
          <>
            <Table
              name="subscription-current-usage-table"
              containerSize={0}
              rowSize={72}
              // Add a small px-1 horizontal padding to every body cell so the
              // hover/active states on the now-clickable rows don't sit flush
              // against the table edges.
              containerClassName="[&_tbody>tr>td]:px-1"
              isLoading={isLoading}
              hasError={hasError}
              // While loading (initial fetch OR refresh via the reload
              // button) we pass an empty data array so the Table's `isLoading`
              // path renders ONLY the skeleton rows. The design-system Table
              // otherwise appends skeletons after the existing rows, leaving
              // stale data visible during refresh — QA flagged this.
              data={isLoading ? [] : usageData?.chargesUsage || []}
              onRowActionClick={(row) =>
                handleOpenUsageDetailDrawer(row as SubscriptionUsageDetailDrawerUsage)
              }
              columns={[
                {
                  key: 'charge.invoiceDisplayName',
                  title: translate('text_1725983967306dtwnapp4mw9'),
                  maxSpace: true,
                  content: (row) => {
                    const filterLabels = (row.filters ?? [])
                      .map((f) => f?.invoiceDisplayName)
                      .filter((label): label is string => !!label)

                    // Pricing group keys ("priced per") and presentation group
                    // keys ("split by") come from the charge config, not from
                    // runtime usage data — so they surface even before the first
                    // fee is recorded.
                    const pricingGroupKeys = row.charge.properties?.pricingGroupKeys ?? []
                    const presentationGroupKeys = (
                      row.charge.properties?.presentationGroupKeys ?? []
                    ).map((k) => k.value)

                    return (
                      <div className="flex flex-col gap-1 py-3">
                        <Typography variant="body" color="grey700">
                          {row.charge.invoiceDisplayName || row.billableMetric?.name}
                        </Typography>
                        <div className="flex flex-wrap items-center gap-1">
                          <Typography variant="caption" color="grey600" component="span">
                            {row.billableMetric?.code}
                          </Typography>

                          {filterLabels.length > 0 && (
                            <Typography variant="caption" color="grey600" component="span">
                              {' • '}
                              {translate('text_1779790016087nsol47cwuwg')}
                            </Typography>
                          )}

                          {pricingGroupKeys.length > 0 && (
                            <>
                              <Typography variant="caption" color="grey600" component="span">
                                {' • '}
                                {translate('text_177883198759933bb02ulslv')}
                              </Typography>
                              {pricingGroupKeys.map((key, i) => (
                                <Fragment key={`pgk-${key}`}>
                                  {i > 0 && (
                                    <Typography variant="caption" color="grey600" component="span">
                                      +
                                    </Typography>
                                  )}
                                  <Chip label={key} size="small" variant="captionCode" />
                                </Fragment>
                              ))}
                            </>
                          )}

                          {presentationGroupKeys.length > 0 && (
                            <>
                              <Typography variant="caption" color="grey600" component="span">
                                {' • '}
                                {translate('text_1778831987599grvoqfl2yd2')}
                              </Typography>
                              {presentationGroupKeys.map((key, i) => (
                                <Fragment key={`presgk-${key}`}>
                                  {i > 0 && (
                                    <Typography variant="caption" color="grey600" component="span">
                                      +
                                    </Typography>
                                  )}
                                  <Chip label={key} size="small" variant="captionCode" />
                                </Fragment>
                              ))}
                            </>
                          )}
                        </div>
                      </div>
                    )
                  },
                },
                {
                  key: 'units',
                  title: TRANSLATION_MAP.unitsHeader,
                  textAlign: 'right',
                  minWidth: 70,
                  content: (row) => (
                    <Typography variant="body" color="grey700">
                      {(row as MixedCharge)?.[unitsKey]}
                    </Typography>
                  ),
                },
                {
                  key: 'amountCents',
                  title: TRANSLATION_MAP.amountHeader,
                  textAlign: 'right',
                  minWidth: 100,
                  content: (row) => {
                    const currencyDisplay = locale ? 'narrowSymbol' : 'symbol'

                    return (
                      <div className="flex flex-col">
                        <Typography variant="bodyHl" color="grey700">
                          {intlFormatNumber(
                            deserializeAmount(
                              getPricingUnitAmountCents(row, showProjected) || 0,
                              currency,
                            ),
                            {
                              currency,
                              locale,
                              currencyDisplay,
                              pricingUnitShortName:
                                row.charge.appliedPricingUnit?.pricingUnit?.shortName,
                            },
                          )}
                        </Typography>

                        {!!row.charge.appliedPricingUnit && (
                          <Typography variant="caption" color="grey600">
                            {intlFormatNumber(
                              deserializeAmount(
                                (row as MixedCharge)?.[amountCentsKey] || 0,
                                currency,
                              ),
                              {
                                currency,
                                locale,
                                currencyDisplay,
                              },
                            )}
                          </Typography>
                        )}
                      </div>
                    )
                  },
                },
              ]}
            />
          </>
        )}

      <SubscriptionUsageDetailDrawer
        ref={subscriptionUsageDetailDrawerRef}
        currency={currency}
        fromDatetime={usageData?.fromDatetime}
        toDatetime={usageData?.toDatetime}
        customerTimezone={customerTimezone}
        translate={translate}
        locale={locale}
      />
    </section>
  )
}

export const SubscriptionCurrentUsageTable = ({
  customerId,
  subscriptionId,
}: SubscriptionCurrentUsageTableProps) => {
  const navigate = useNavigate()
  const { planId = '' } = useParams()
  const { translate } = useInternationalization()
  const { organization: { premiumIntegrations } = {} } = useOrganizationInfos()
  const [activeTab, setActiveTab] = useState<number>(0)

  const hasAccessToProjectedUsage = !!premiumIntegrations?.includes(
    PremiumIntegrationTypeEnum.ProjectedUsage,
  )

  const {
    data: customerData,
    loading: customerLoading,
    error: customerError,
  } = useCustomerForSubscriptionUsageQuery({
    variables: { customerId },
    skip: !customerId,
  })

  const {
    data: subscriptionData,
    loading: subscriptionLoading,
    error: subscriptionError,
  } = useSubscrptionForSubscriptionUsageQuery({
    variables: { subscription: subscriptionId },
  })

  const subscription = subscriptionData?.subscription

  // When the user has premium access, always fetch the projected query so the
  // summary panel can show the projected end-of-period value on the Current
  // tab too. The projected query is a superset of the current one (it returns
  // both `amountCents` and `projectedAmountCents`), so non-premium users
  // continue to use the lighter current-only query.
  const fetchProjected = hasAccessToProjectedUsage

  const queryParams = {
    context: {
      silentErrorCodes: [LagoApiError.UnprocessableEntity, LagoApiError.NoActiveSubscription],
    },
    variables: {
      customerId: (customerId || subscription?.customer.id) as string,
      subscriptionId: subscription?.id || '',
    },
    skip: !customerId || !subscription || subscription.status === StatusTypeEnum.Pending,
    notifyOnNetworkStatusChange: true,
  }

  const {
    data: usageData,
    loading: usageLoading,
    error: usageError,
    refetch: refetchUsageQuery,
  } = useUsageForSubscriptionUsageQuery({
    ...queryParams,
    skip: queryParams.skip || fetchProjected,
    // Removing the no-cache policies will break the rendered data
    fetchPolicy: 'no-cache',
    nextFetchPolicy: 'no-cache',
  })

  const {
    data: usageDataProjected,
    loading: usageLoadingProjected,
    error: usageErrorProjected,
    refetch: refetchUsageQueryProjected,
  } = useProjectedUsageForSubscriptionUsageQuery({
    ...queryParams,
    skip: queryParams.skip || !fetchProjected,
    // Removing the no-cache policies will break the rendered data
    fetchPolicy: 'no-cache',
    nextFetchPolicy: 'no-cache',
  })

  const refetchUsage = (forceProjected?: boolean) =>
    fetchProjected || forceProjected ? refetchUsageQueryProjected() : refetchUsageQuery()

  useEffect(() => {
    if (
      hasDefinedGQLError('NoActiveSubscription', usageError) ||
      hasDefinedGQLError('NoActiveSubscription', usageErrorProjected)
    ) {
      addToast({
        severity: 'info',
        translateKey: 'text_173142196943714qsq737sre',
      })

      const overviewPath = !!customerId
        ? generatePath(CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE, {
            customerId,
            subscriptionId,
            tab: CustomerSubscriptionDetailsTabsOptionsEnum.overview,
          })
        : generatePath(PLAN_SUBSCRIPTION_DETAILS_ROUTE, {
            planId,
            subscriptionId,
            tab: CustomerSubscriptionDetailsTabsOptionsEnum.overview,
          })

      navigate(overviewPath, { replace: true })
    }
  }, [usageError, usageErrorProjected, navigate, customerId, planId, subscriptionId])

  return (
    <SubscriptionCurrentUsageTableComponent
      activeTab={activeTab}
      setActiveTab={setActiveTab}
      customerData={customerData?.customer}
      customerLoading={customerLoading}
      customerError={customerError}
      subscription={subscription}
      subscriptionLoading={subscriptionLoading}
      subscriptionError={subscriptionError}
      usageData={
        (usageDataProjected?.customerProjectedUsage || usageData?.customerUsage) as UsageData
      }
      usageLoading={usageLoadingProjected || usageLoading}
      usageError={usageErrorProjected || usageError}
      refetchUsage={refetchUsage}
      translate={translate}
      hasAccessToProjectedUsage={hasAccessToProjectedUsage}
    />
  )
}
