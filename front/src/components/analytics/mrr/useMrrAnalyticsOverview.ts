import { gql } from '@apollo/client'
import Decimal from 'decimal.js'
import { DateTime } from 'luxon'
import { useCallback, useMemo } from 'react'
import { useSearchParams } from 'react-router-dom'

import {
  formattedMrrDataForAreaChartLoadingFixture,
  formattedMrrDataLoadingFixture,
} from '~/components/analytics/mrr/fixture'
import { formatMrrData, formatMrrDataForAreaChart } from '~/components/analytics/mrr/utils'
import { AvailableFiltersEnum } from '~/components/designSystem/Filters'
import { formatFiltersForMrrQuery, getFilterValue } from '~/components/designSystem/Filters/utils'
import { AreaChartDataType } from '~/components/designSystem/graphs/types'
import { MRR_BREAKDOWN_OVERVIEW_FILTER_PREFIX } from '~/core/constants/filters'
import { getTimezoneConfig } from '~/core/timezone'
import {
  CurrencyEnum,
  MrrDataForOverviewSectionFragment,
  MrrDataForOverviewSectionFragmentDoc,
  PremiumIntegrationTypeEnum,
  TimeGranularityEnum,
  TimezoneEnum,
  useGetMrrsQuery,
} from '~/generated/graphql'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

gql`
  query getMrrs(
    $currency: CurrencyEnum
    $customerCountry: CountryCode
    $customerType: CustomerTypeEnum
    $externalCustomerId: String
    $fromDate: ISO8601Date
    $planCode: String
    $timeGranularity: TimeGranularityEnum
    $toDate: ISO8601Date
    $billingEntityCode: String
    $isCustomerTinEmpty: Boolean
  ) {
    dataApiMrrs(
      currency: $currency
      customerCountry: $customerCountry
      customerType: $customerType
      externalCustomerId: $externalCustomerId
      fromDate: $fromDate
      planCode: $planCode
      timeGranularity: $timeGranularity
      toDate: $toDate
      billingEntityCode: $billingEntityCode
      isCustomerTinEmpty: $isCustomerTinEmpty
    ) {
      collection {
        ...MrrDataForOverviewSection
      }
    }
  }

  ${MrrDataForOverviewSectionFragmentDoc}
`

type MrrAnalyticsOverviewReturn = {
  selectedCurrency: CurrencyEnum
  defaultCurrency: CurrencyEnum
  data: MrrDataForOverviewSectionFragment[]
  formattedDataForAreaChart: AreaChartDataType[]
  hasAccessToAnalyticsDashboardsFeature: boolean
  hasError: boolean
  isLoading: boolean
  lastMrrAmountCents: string
  mrrAmountCentsProgressionOnPeriod: string
  timeGranularity: TimeGranularityEnum
  getDefaultStaticDateFilter: () => string
  getDefaultStaticTimeGranularityFilter: () => string
}

const getFilterByKey = (key: AvailableFiltersEnum, searchParams: URLSearchParams) => {
  return getFilterValue({
    key,
    searchParams,
    prefix: MRR_BREAKDOWN_OVERVIEW_FILTER_PREFIX,
  })
}

export const useMrrAnalyticsOverview = (): MrrAnalyticsOverviewReturn => {
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

  const filtersForMrrQuery = useMemo(() => {
    if (!hasAccessToAnalyticsDashboardsFeature) {
      return {
        currency: defaultCurrency,
        date: getDefaultStaticDateFilter(),
        timeGranularity: getDefaultStaticTimeGranularityFilter(),
      }
    }

    return formatFiltersForMrrQuery(searchParams)
  }, [
    hasAccessToAnalyticsDashboardsFeature,
    searchParams,
    defaultCurrency,
    getDefaultStaticDateFilter,
    getDefaultStaticTimeGranularityFilter,
  ])

  const {
    data: mrrData,
    loading: mrrLoading,
    error: mrrError,
  } = useGetMrrsQuery({
    notifyOnNetworkStatusChange: true,
    variables: {
      ...filtersForMrrQuery,
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

  const { formattedMrrData, formattedDataForAreaChart } = useMemo(() => {
    if (!mrrData?.dataApiMrrs.collection && !!mrrLoading) {
      return {
        formattedMrrData: formattedMrrDataLoadingFixture,
        formattedDataForAreaChart: formattedMrrDataForAreaChartLoadingFixture,
      }
    }

    const localFormattedMrrData = formatMrrData({
      searchParams,
      data: mrrData?.dataApiMrrs.collection,
      defaultStaticDatePeriod: getDefaultStaticDateFilter(),
      defaultStaticTimeGranularity: getDefaultStaticTimeGranularityFilter(),
    })

    const localFormattedDataForAreaChart = formatMrrDataForAreaChart({
      data: localFormattedMrrData || [],
      timeGranularity,
      selectedCurrency,
    })

    return {
      formattedMrrData: localFormattedMrrData,
      formattedDataForAreaChart: localFormattedDataForAreaChart,
    }
  }, [
    getDefaultStaticDateFilter,
    getDefaultStaticTimeGranularityFilter,
    mrrData?.dataApiMrrs.collection,
    mrrLoading,
    searchParams,
    selectedCurrency,
    timeGranularity,
  ])

  const { lastMrrAmountCents, mrrAmountCentsProgressionOnPeriod } = useMemo(() => {
    if (!formattedMrrData?.length) {
      return {
        lastMrrAmountCents: '0',
        mrrAmountCentsProgressionOnPeriod: '0',
      }
    }

    const localFirstMrrAmountCents = Number(formattedMrrData[0]?.endingMrr)
    const localLastMrrAmountCents: string =
      formattedMrrData[formattedMrrData?.length - 1]?.endingMrr

    // Bellow calcul should *100 but values are already in cents so no need to do it
    // Also explain why the toFixed is 4 and not 2
    const localLastMrrAmountCentsProgressionOnPeriod = new Decimal(
      Number(localLastMrrAmountCents || 0),
    )
      .sub(localFirstMrrAmountCents)
      .dividedBy(localFirstMrrAmountCents || 1)
      .toFixed(4)

    return {
      lastMrrAmountCents: localLastMrrAmountCents,
      mrrAmountCentsProgressionOnPeriod: localLastMrrAmountCentsProgressionOnPeriod,
    }
  }, [formattedMrrData])

  return {
    defaultCurrency,
    hasAccessToAnalyticsDashboardsFeature,
    lastMrrAmountCents,
    mrrAmountCentsProgressionOnPeriod,
    selectedCurrency,
    timeGranularity,
    data: formattedMrrData,
    formattedDataForAreaChart,
    hasError: !!mrrError && !mrrLoading,
    isLoading: mrrLoading,
    getDefaultStaticDateFilter,
    getDefaultStaticTimeGranularityFilter,
  }
}
