import { DateTime, DateTimeUnit, Duration, DurationUnit, Interval } from 'luxon'

import { AvailableFiltersEnum, getFilterValue } from '~/components/designSystem/Filters'
import { AreaChartDataType } from '~/components/designSystem/graphs/types'
import { getItemDateFormatedByTimeGranularity } from '~/components/designSystem/graphs/utils'
import { ANALYTICS_USAGE_OVERVIEW_FILTER_PREFIX } from '~/core/constants/filters'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { DateFormat, intlFormatDateTime } from '~/core/timezone/utils'
import {
  CurrencyEnum,
  DataApiUsage,
  DataApiUsageAggregatedAmount,
  TimeGranularityEnum,
} from '~/generated/graphql'

const DIFF_CURSOR: Record<TimeGranularityEnum, DurationUnit> = {
  [TimeGranularityEnum.Daily]: 'days',
  [TimeGranularityEnum.Weekly]: 'weeks',
  [TimeGranularityEnum.Monthly]: 'months',
} as const

export const formatUsageData = ({
  data,
  searchParams,
  defaultStaticDatePeriod,
  defaultStaticTimeGranularity,
  filtersPrefix,
  emptyItem,
}: {
  data: DataApiUsage[] | undefined
  searchParams: URLSearchParams
  defaultStaticDatePeriod: string
  defaultStaticTimeGranularity: string
  filtersPrefix?: string
  emptyItem?: DataApiUsage
}): {
  startOfPeriodDt: string | null
  endOfPeriodDt: string | null
  amountCents: number
  units: number
}[] => {
  const datePeriod =
    getFilterValue({
      key: AvailableFiltersEnum.date,
      searchParams,
      prefix: filtersPrefix ?? ANALYTICS_USAGE_OVERVIEW_FILTER_PREFIX,
    }) || defaultStaticDatePeriod

  const timeGranularity = (getFilterValue({
    key: AvailableFiltersEnum.timeGranularity,
    searchParams,
    prefix: filtersPrefix ?? ANALYTICS_USAGE_OVERVIEW_FILTER_PREFIX,
  }) || defaultStaticTimeGranularity) as TimeGranularityEnum

  const [startDate, endDate] = datePeriod.split(',')

  const diffCursor = DIFF_CURSOR[timeGranularity]

  const intervalData = Interval.fromDateTimes(
    DateTime.fromISO(startDate).startOf(diffCursor as DateTimeUnit),
    DateTime.fromISO(endDate).endOf(diffCursor as DateTimeUnit),
  )
    .splitBy(Duration.fromDurationLike({ [diffCursor]: 1 }))
    .map((i) => i.toISODate())

  const paddedData = intervalData.map((interval, index) => {
    const [start, end = ''] = interval.split('/')

    const readableEnd =
      timeGranularity === TimeGranularityEnum.Weekly && index !== intervalData.length - 1
        ? DateTime.fromISO(end).minus({ day: 1 }).toISODate()
        : end
    const foundDataWithSamePeriod = data?.find((d) => d.startOfPeriodDt === start)

    if (foundDataWithSamePeriod) {
      return foundDataWithSamePeriod
    }

    const emptyData: DataApiUsage = emptyItem ?? {
      startOfPeriodDt: start,
      endOfPeriodDt: readableEnd,
      amountCents: 0,
      units: 0,
      amountCurrency: CurrencyEnum.Usd,
      billableMetricCode: '',
      isBillableMetricDeleted: false,
    }

    return emptyData
  })

  return paddedData
}

export const formatAggregatedUsageData = ({
  data,
  searchParams,
  defaultStaticDatePeriod,
  defaultStaticTimeGranularity,
  filtersPrefix,
  emptyItem,
}: {
  data: DataApiUsageAggregatedAmount[] | undefined
  searchParams: URLSearchParams
  defaultStaticDatePeriod: string
  defaultStaticTimeGranularity: string
  filtersPrefix?: string
  emptyItem?: DataApiUsageAggregatedAmount
}): DataApiUsageAggregatedAmount[] => {
  const datePeriod =
    getFilterValue({
      key: AvailableFiltersEnum.date,
      searchParams,
      prefix: filtersPrefix ?? ANALYTICS_USAGE_OVERVIEW_FILTER_PREFIX,
    }) || defaultStaticDatePeriod

  const timeGranularity = (getFilterValue({
    key: AvailableFiltersEnum.timeGranularity,
    searchParams,
    prefix: filtersPrefix ?? ANALYTICS_USAGE_OVERVIEW_FILTER_PREFIX,
  }) || defaultStaticTimeGranularity) as TimeGranularityEnum

  const [startDate, endDate] = datePeriod.split(',')

  const diffCursor = DIFF_CURSOR[timeGranularity]

  const intervalData = Interval.fromDateTimes(
    DateTime.fromISO(startDate).startOf(diffCursor as DateTimeUnit),
    DateTime.fromISO(endDate).endOf(diffCursor as DateTimeUnit),
  )
    .splitBy(Duration.fromDurationLike({ [diffCursor]: 1 }))
    .map((i) => i.toISODate())

  const paddedData = intervalData.map((interval, index) => {
    const [start, end = ''] = interval.split('/')

    const readableEnd =
      timeGranularity === TimeGranularityEnum.Weekly && index !== intervalData.length - 1
        ? DateTime.fromISO(end).minus({ day: 1 }).toISODate()
        : end
    const foundDataWithSamePeriod = data?.find((d) => d.startOfPeriodDt === start)

    if (foundDataWithSamePeriod) {
      return foundDataWithSamePeriod
    }

    const emptyData: DataApiUsageAggregatedAmount = emptyItem ?? {
      startOfPeriodDt: start,
      endOfPeriodDt: readableEnd,
      amountCents: 0,
      amountCurrency: CurrencyEnum.Usd,
    }

    return emptyData
  })

  return paddedData
}

export const formatUsageDataForAreaChart = ({
  data,
  timeGranularity,
  selectedCurrency,
}: {
  data: DataApiUsage[] | DataApiUsageAggregatedAmount[]
  timeGranularity: TimeGranularityEnum
  selectedCurrency: CurrencyEnum
}): AreaChartDataType[] => {
  return data.map((item, index) => ({
    tooltipLabel: `${getItemDateFormatedByTimeGranularity({
      item,
      timeGranularity,
    })}: ${intlFormatNumber(deserializeAmount(item.amountCents, selectedCurrency), {
      currency: selectedCurrency,
    })}`,
    value: Number(item.amountCents),
    axisName: intlFormatDateTime(index === 0 ? item.startOfPeriodDt : item.endOfPeriodDt, {
      formatDate: DateFormat.DATE_MED,
    }).date,
  }))
}

export const formatUsageBillableMetricData = ({
  data,
  searchParams,
  defaultStaticDatePeriod,
  defaultStaticTimeGranularity,
  filtersPrefix,
  emptyItem,
}: {
  data?: DataApiUsage[]
  searchParams: URLSearchParams
  defaultStaticDatePeriod: string
  defaultStaticTimeGranularity: string
  filtersPrefix?: string
  emptyItem?: DataApiUsage
}): {
  startOfPeriodDt: string
  endOfPeriodDt: string
  amountCents: number
  units: number
}[] => {
  const datePeriod =
    getFilterValue({
      key: AvailableFiltersEnum.date,
      searchParams,
      prefix: filtersPrefix ?? ANALYTICS_USAGE_OVERVIEW_FILTER_PREFIX,
    }) || defaultStaticDatePeriod

  const timeGranularity = (getFilterValue({
    key: AvailableFiltersEnum.timeGranularity,
    searchParams,
    prefix: filtersPrefix ?? ANALYTICS_USAGE_OVERVIEW_FILTER_PREFIX,
  }) || defaultStaticTimeGranularity) as TimeGranularityEnum

  const [startDate, endDate] = datePeriod.split(',')

  const diffCursor = DIFF_CURSOR[timeGranularity]

  const intervalData = Interval.fromDateTimes(
    DateTime.fromISO(startDate).startOf(diffCursor as DateTimeUnit),
    DateTime.fromISO(endDate).endOf(diffCursor as DateTimeUnit),
  )
    .splitBy(Duration.fromDurationLike({ [diffCursor]: 1 }))
    .map((i) => i.toISODate())

  const paddedData = intervalData.map((interval, index) => {
    const [start, end = ''] = interval.split('/')

    const readableEnd =
      timeGranularity === TimeGranularityEnum.Weekly && index !== intervalData.length - 1
        ? DateTime.fromISO(end).minus({ day: 1 }).toISODate()
        : end
    const foundDataWithSamePeriod = data?.find((d) => d.startOfPeriodDt === start)

    if (foundDataWithSamePeriod) {
      return foundDataWithSamePeriod
    }

    const emptyData: DataApiUsage = emptyItem ?? {
      startOfPeriodDt: start,
      endOfPeriodDt: readableEnd,
      amountCents: 0,
      units: 0,
      amountCurrency: CurrencyEnum.Usd,
      billableMetricCode: '',
      isBillableMetricDeleted: false,
    }

    return emptyData
  })

  return paddedData
}
