import { gql } from '@apollo/client'
import Decimal from 'decimal.js'
import { DateTime } from 'luxon'
import { useCallback, useMemo } from 'react'
import { useSearchParams } from 'react-router-dom'

import { formatRevenueStreamsData } from '~/components/analytics/revenueStreams/utils'
import { AvailableFiltersEnum } from '~/components/designSystem/Filters'
import {
  formatFiltersForRevenueStreamsQuery,
  getFilterValue,
} from '~/components/designSystem/Filters/utils'
import { REVENUE_STREAMS_OVERVIEW_FILTER_PREFIX } from '~/core/constants/filters'
import { getTimezoneConfig } from '~/core/timezone'
import {
  CurrencyEnum,
  PremiumIntegrationTypeEnum,
  RevenueStreamDataForOverviewSectionFragment,
  RevenueStreamDataForOverviewSectionFragmentDoc,
  TimeGranularityEnum,
  TimezoneEnum,
  useGetRevenueStreamsQuery,
} from '~/generated/graphql'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

gql`
  query getRevenueStreams(
    $currency: CurrencyEnum
    $customerCountry: CountryCode
    $customerType: CustomerTypeEnum
    $isCustomerTinEmpty: Boolean
    $externalCustomerId: String
    $externalSubscriptionId: String
    $fromDate: ISO8601Date
    $planCode: String
    $timeGranularity: TimeGranularityEnum
    $toDate: ISO8601Date
    $billingEntityCode: String
  ) {
    dataApiRevenueStreams(
      currency: $currency
      customerCountry: $customerCountry
      customerType: $customerType
      externalCustomerId: $externalCustomerId
      externalSubscriptionId: $externalSubscriptionId
      fromDate: $fromDate
      planCode: $planCode
      timeGranularity: $timeGranularity
      toDate: $toDate
      billingEntityCode: $billingEntityCode
      isCustomerTinEmpty: $isCustomerTinEmpty
    ) {
      collection {
        ...RevenueStreamDataForOverviewSection
      }
    }
  }

  ${RevenueStreamDataForOverviewSectionFragmentDoc}
`

type RevenueAnalyticsOverviewReturn = {
  selectedCurrency: CurrencyEnum
  defaultCurrency: CurrencyEnum
  data: RevenueStreamDataForOverviewSectionFragment[]
  hasAccessToAnalyticsDashboardsFeature: boolean
  hasError: boolean
  isLoading: boolean
  lastNetRevenueAmountCents: string
  netRevenueAmountCentsProgressionOnPeriod: string
  timeGranularity: TimeGranularityEnum
  getDefaultStaticDateFilter: () => string
  getDefaultStaticTimeGranularityFilter: () => string
}

const getFilterByKey = (key: AvailableFiltersEnum, searchParams: URLSearchParams) => {
  return getFilterValue({
    key,
    searchParams,
    prefix: REVENUE_STREAMS_OVERVIEW_FILTER_PREFIX,
  })
}

export const useRevenueAnalyticsOverview = (): RevenueAnalyticsOverviewReturn => {
  const [searchParams] = useSearchParams()
  const { organization, hasOrganizationPremiumAddon } = useOrganizationInfos()

  const hasAccessToAnalyticsDashboardsFeature = hasOrganizationPremiumAddon(
    PremiumIntegrationTypeEnum.AnalyticsDashboards,
  )

  const defaultCurrency = organization?.defaultCurrency || CurrencyEnum.Usd

  const getDefaultStaticDateFilter = useCallback((): string => {
    const now = DateTime.now().setZone(getTimezoneConfig(TimezoneEnum.TzUtc).name)

    if (!hasAccessToAnalyticsDashboardsFeature) {
      return `${now.minus({ month: 1 }).startOf('day').toISO()},${now.endOf('day').toISO()}`
    }

    return `${now.minus({ month: 12 }).startOf('day').toISO()},${now.endOf('day').toISO()}`
  }, [hasAccessToAnalyticsDashboardsFeature])

  const getDefaultStaticTimeGranularityFilter = useCallback((): TimeGranularityEnum => {
    if (!hasAccessToAnalyticsDashboardsFeature) {
      return TimeGranularityEnum.Daily
    }

    return TimeGranularityEnum.Monthly
  }, [hasAccessToAnalyticsDashboardsFeature])

  const filtersForRevenueStreamsQuery = useMemo(() => {
    if (!hasAccessToAnalyticsDashboardsFeature) {
      return {
        currency: defaultCurrency,
        date: getDefaultStaticDateFilter(),
        timeGranularity: getDefaultStaticTimeGranularityFilter(),
      }
    }

    return formatFiltersForRevenueStreamsQuery(searchParams)
  }, [
    hasAccessToAnalyticsDashboardsFeature,
    searchParams,
    defaultCurrency,
    getDefaultStaticDateFilter,
    getDefaultStaticTimeGranularityFilter,
  ])

  const {
    data: revenueStreamsData,
    loading: revenueStreamsLoading,
    error: revenueStreamsError,
  } = useGetRevenueStreamsQuery({
    notifyOnNetworkStatusChange: true,
    variables: {
      ...filtersForRevenueStreamsQuery,
    },
  })

  const timeGranularity = getFilterByKey(
    AvailableFiltersEnum.timeGranularity,
    searchParams,
  ) as TimeGranularityEnum

  const selectedCurrency = useMemo(() => {
    const currencyFromFilter = getFilterByKey(AvailableFiltersEnum.currency, searchParams)

    if (!!currencyFromFilter) {
      return currencyFromFilter as CurrencyEnum
    }
    return defaultCurrency
  }, [searchParams, defaultCurrency])

  const formattedRevenueStreamsData = useMemo(() => {
    return formatRevenueStreamsData({
      searchParams,
      data: revenueStreamsData?.dataApiRevenueStreams.collection,
      defaultStaticDatePeriod: getDefaultStaticDateFilter(),
      defaultStaticTimeGranularity: getDefaultStaticTimeGranularityFilter(),
    })
  }, [
    getDefaultStaticDateFilter,
    getDefaultStaticTimeGranularityFilter,
    revenueStreamsData?.dataApiRevenueStreams.collection,
    searchParams,
  ])

  const { lastNetRevenueAmountCents, netRevenueAmountCentsProgressionOnPeriod } = useMemo(() => {
    if (!formattedRevenueStreamsData?.length) {
      return {
        lastNetRevenueAmountCents: '0',
        netRevenueAmountCentsProgressionOnPeriod: '0',
      }
    }

    const localFirstNetRevenueAmountCents = Number(
      formattedRevenueStreamsData[0]?.netRevenueAmountCents,
    )
    const localLastNetRevenueAmountCents: string =
      formattedRevenueStreamsData[formattedRevenueStreamsData?.length - 1]?.netRevenueAmountCents

    // Bellow calcul should *100 but values are already in cents so no need to do it
    // Also explain why the toFixed is 4 and not 2
    const localNetRevenueAmountCentsProgressionOnPeriod = new Decimal(
      Number(localLastNetRevenueAmountCents || 0),
    )
      .sub(localFirstNetRevenueAmountCents)
      .dividedBy(localFirstNetRevenueAmountCents || 1)
      .toFixed(4)

    return {
      lastNetRevenueAmountCents: localLastNetRevenueAmountCents,
      netRevenueAmountCentsProgressionOnPeriod: localNetRevenueAmountCentsProgressionOnPeriod,
    }
  }, [formattedRevenueStreamsData])

  return {
    defaultCurrency,
    hasAccessToAnalyticsDashboardsFeature,
    lastNetRevenueAmountCents,
    netRevenueAmountCentsProgressionOnPeriod,
    selectedCurrency,
    timeGranularity,
    data: formattedRevenueStreamsData,
    hasError: !!revenueStreamsError && !revenueStreamsLoading,
    isLoading: revenueStreamsLoading,
    getDefaultStaticDateFilter,
    getDefaultStaticTimeGranularityFilter,
  }
}
