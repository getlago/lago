import { gql } from '@apollo/client'
import { DateTime } from 'luxon'
import { useCallback, useMemo } from 'react'
import { useSearchParams } from 'react-router-dom'

import { UsageBreakdownType } from '~/components/analytics/usage/types'
import { useUsageAnalyticsBreakdown } from '~/components/analytics/usage/useUsageAnalyticsBreakdown'
import { formatUsageBillableMetricData } from '~/components/analytics/usage/utils'
import {
  AvailableFiltersEnum,
  formatFiltersForUsageBillableMetricQuery,
  getFilterValue,
} from '~/components/designSystem/Filters'
import { ANALYTICS_USAGE_BILLABLE_METRIC_FILTER_PREFIX } from '~/core/constants/filters'
import { getTimezoneConfig } from '~/core/timezone'
import {
  CurrencyEnum,
  DataApiUsage,
  PremiumIntegrationTypeEnum,
  TimeGranularityEnum,
  TimezoneEnum,
  useGetUsageBillableMetricQuery,
} from '~/generated/graphql'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

gql`
  query getUsageBillableMetric(
    $currency: CurrencyEnum
    $timeGranularity: TimeGranularityEnum
    $fromDate: ISO8601Date
    $toDate: ISO8601Date
    $billableMetricCode: String
  ) {
    dataApiUsages(
      currency: $currency
      timeGranularity: $timeGranularity
      fromDate: $fromDate
      toDate: $toDate
      billableMetricCode: $billableMetricCode
    ) {
      collection {
        amountCents
        amountCurrency
        endOfPeriodDt
        startOfPeriodDt
        units
      }
    }
  }
`

const getFilterByKey = (key: AvailableFiltersEnum, searchParams: URLSearchParams) => {
  return getFilterValue({
    key,
    searchParams,
    prefix: ANALYTICS_USAGE_BILLABLE_METRIC_FILTER_PREFIX,
  })
}

type UseUsageAnalyticsBillableMetricProps = {
  billableMetricCode: string
  breakdownType: UsageBreakdownType
}

export const useUsageAnalyticsBillableMetric = ({
  billableMetricCode,
  breakdownType,
}: UseUsageAnalyticsBillableMetricProps) => {
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

    return `${now.minus({ days: 30 }).startOf('day').toISO()},${now.endOf('day').toISO()}`
  }, [hasAccessToAnalyticsDashboardsFeature])

  const getDefaultStaticTimeGranularityFilter = useCallback((): TimeGranularityEnum => {
    return TimeGranularityEnum.Daily
  }, [])

  const filtersForUsageBillableMetricQuery = useMemo(() => {
    if (!hasAccessToAnalyticsDashboardsFeature) {
      return {
        currency: defaultCurrency,
        date: getDefaultStaticDateFilter(),
        timeGranularity: getDefaultStaticTimeGranularityFilter(),
      }
    }

    return formatFiltersForUsageBillableMetricQuery(searchParams)
  }, [
    hasAccessToAnalyticsDashboardsFeature,
    searchParams,
    defaultCurrency,
    getDefaultStaticDateFilter,
    getDefaultStaticTimeGranularityFilter,
  ])

  const {
    data: usageData,
    loading: usageLoading,
    error: usageError,
  } = useGetUsageBillableMetricQuery({
    notifyOnNetworkStatusChange: true,
    variables: {
      ...filtersForUsageBillableMetricQuery,
      billableMetricCode,
    },
    skip: !billableMetricCode,
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

  const { valueKey, displayFormat } = useUsageAnalyticsBreakdown({
    availableFilters: [],
    filtersPrefix: '',
    breakdownType,
    showDeletedBillableMetrics: true,
  })

  const { formattedUsageData, total } = useMemo(() => {
    const sum = (arr: Array<{ amountCents: number; units: number }>) =>
      arr.reduce((p, c) => p + Number(c[valueKey as 'amountCents' | 'units']), 0)

    const collection = usageData?.dataApiUsages?.collection

    if (!collection && !!usageLoading) {
      return {
        total: 0,
      }
    }

    const localFormattedUsageData = formatUsageBillableMetricData({
      searchParams,
      data: collection as DataApiUsage[],
      defaultStaticDatePeriod: getDefaultStaticDateFilter(),
      defaultStaticTimeGranularity: getDefaultStaticTimeGranularityFilter(),
      filtersPrefix: ANALYTICS_USAGE_BILLABLE_METRIC_FILTER_PREFIX,
    })

    return {
      formattedUsageData: localFormattedUsageData,
      total: sum(localFormattedUsageData),
    }
  }, [
    getDefaultStaticDateFilter,
    getDefaultStaticTimeGranularityFilter,
    usageData?.dataApiUsages?.collection,
    usageLoading,
    searchParams,
    valueKey,
  ])

  return {
    data: formattedUsageData,
    defaultCurrency,
    hasAccessToAnalyticsDashboardsFeature,
    selectedCurrency,
    timeGranularity,
    hasError: !!usageError && !usageLoading,
    isLoading: usageLoading,
    getDefaultStaticDateFilter,
    getDefaultStaticTimeGranularityFilter,
    total,
    valueKey,
    displayFormat,
  }
}
