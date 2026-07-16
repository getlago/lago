import { gql } from '@apollo/client'
import { DateTime } from 'luxon'
import { useCallback, useMemo } from 'react'
import { useSearchParams } from 'react-router-dom'

import { formattedPrepaidCreditsDataLoadingFixture } from '~/components/analytics/prepaidCredits/fixture'
import { formatPrepaidCreditsData } from '~/components/analytics/prepaidCredits/utils'
import { AvailableFiltersEnum } from '~/components/designSystem/Filters'
import {
  formatFiltersForPrepaidCreditsQuery,
  getFilterValue,
} from '~/components/designSystem/Filters/utils'
import { PREPAID_CREDITS_OVERVIEW_FILTER_PREFIX } from '~/core/constants/filters'
import { getTimezoneConfig } from '~/core/timezone'
import {
  CurrencyEnum,
  PremiumIntegrationTypeEnum,
  PrepaidCreditsDataForOverviewSectionFragment,
  PrepaidCreditsDataForOverviewSectionFragmentDoc,
  TimeGranularityEnum,
  TimezoneEnum,
  useGetPrepaidCreditsQuery,
} from '~/generated/graphql'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

gql`
  query getPrepaidCredits(
    $currency: CurrencyEnum
    $customerCountry: CountryCode
    $customerType: CustomerTypeEnum
    $externalCustomerId: String
    $externalSubscriptionId: String
    $fromDate: ISO8601Date
    $planCode: String
    $timeGranularity: TimeGranularityEnum
    $toDate: ISO8601Date
    $billingEntityCode: String
    $isCustomerTinEmpty: Boolean
  ) {
    dataApiPrepaidCredits(
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
        ...PrepaidCreditsDataForOverviewSection
      }
    }
  }

  ${PrepaidCreditsDataForOverviewSectionFragmentDoc}
`

type PrepaidCreditsAnalyticsOverviewReturn = {
  selectedCurrency: CurrencyEnum
  defaultCurrency: CurrencyEnum
  data: PrepaidCreditsDataForOverviewSectionFragment[]
  hasError: boolean
  isLoading: boolean
  timeGranularity: TimeGranularityEnum
  getDefaultStaticDateFilter: () => string
  getDefaultStaticTimeGranularityFilter: () => string
  hasAccessToAnalyticsDashboardsFeature: boolean
}

const getFilterByKey = (key: AvailableFiltersEnum, searchParams: URLSearchParams) => {
  return getFilterValue({
    key,
    searchParams,
    prefix: PREPAID_CREDITS_OVERVIEW_FILTER_PREFIX,
  })
}

export const usePrepaidCreditsAnalyticsOverview = (): PrepaidCreditsAnalyticsOverviewReturn => {
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

  const filtersForPrepaidCreditsQuery = useMemo(() => {
    if (!hasAccessToAnalyticsDashboardsFeature) {
      return {
        currency: defaultCurrency,
        date: getDefaultStaticDateFilter(),
        timeGranularity: getDefaultStaticTimeGranularityFilter(),
      }
    }

    return formatFiltersForPrepaidCreditsQuery(searchParams)
  }, [
    hasAccessToAnalyticsDashboardsFeature,
    searchParams,
    defaultCurrency,
    getDefaultStaticDateFilter,
    getDefaultStaticTimeGranularityFilter,
  ])

  const {
    data: prepaidCreditsData,
    loading: prepaidCreditsLoading,
    error: prepaidCreditsError,
  } = useGetPrepaidCreditsQuery({
    notifyOnNetworkStatusChange: true,
    variables: {
      ...filtersForPrepaidCreditsQuery,
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

  const { formattedPrepaidCreditsData } = useMemo(() => {
    if (!prepaidCreditsData?.dataApiPrepaidCredits.collection && !!prepaidCreditsLoading) {
      return {
        formattedPrepaidCreditsData: formattedPrepaidCreditsDataLoadingFixture,
      }
    }

    const localFormattedPrepaidCreditsData = formatPrepaidCreditsData({
      searchParams,
      data: prepaidCreditsData?.dataApiPrepaidCredits?.collection,
      defaultStaticDatePeriod: getDefaultStaticDateFilter(),
      defaultStaticTimeGranularity: getDefaultStaticTimeGranularityFilter(),
      currency: selectedCurrency,
    })

    return {
      formattedPrepaidCreditsData: localFormattedPrepaidCreditsData,
    }
  }, [
    getDefaultStaticDateFilter,
    getDefaultStaticTimeGranularityFilter,
    prepaidCreditsData?.dataApiPrepaidCredits.collection,
    prepaidCreditsLoading,
    searchParams,
    selectedCurrency,
  ])

  return {
    selectedCurrency,
    defaultCurrency,
    data: formattedPrepaidCreditsData,
    hasError: !!prepaidCreditsError && !prepaidCreditsLoading,
    isLoading: prepaidCreditsLoading,
    timeGranularity,
    getDefaultStaticDateFilter,
    getDefaultStaticTimeGranularityFilter,
    hasAccessToAnalyticsDashboardsFeature,
  }
}
