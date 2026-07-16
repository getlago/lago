import { DateTime, DateTimeUnit, Duration, DurationUnit, Interval } from 'luxon'

import { AvailableFiltersEnum, getFilterValue } from '~/components/designSystem/Filters'
import { AreaChartDataType } from '~/components/designSystem/graphs/types'
import { getItemDateFormatedByTimeGranularity } from '~/components/designSystem/graphs/utils'
import { MRR_BREAKDOWN_OVERVIEW_FILTER_PREFIX } from '~/core/constants/filters'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { DateFormat, intlFormatDateTime } from '~/core/timezone/utils'
import {
  CurrencyEnum,
  MrrDataForOverviewSectionFragment,
  TimeGranularityEnum,
} from '~/generated/graphql'

const DIFF_CURSOR: Record<TimeGranularityEnum, DurationUnit> = {
  [TimeGranularityEnum.Daily]: 'days',
  [TimeGranularityEnum.Weekly]: 'weeks',
  [TimeGranularityEnum.Monthly]: 'months',
} as const

export const formatMrrData = ({
  data,
  searchParams,
  defaultStaticDatePeriod,
  defaultStaticTimeGranularity,
}: {
  data: MrrDataForOverviewSectionFragment[] | undefined
  searchParams: URLSearchParams
  defaultStaticDatePeriod: string
  defaultStaticTimeGranularity: string
}): MrrDataForOverviewSectionFragment[] => {
  const datePeriod =
    getFilterValue({
      key: AvailableFiltersEnum.date,
      searchParams,
      prefix: MRR_BREAKDOWN_OVERVIEW_FILTER_PREFIX,
    }) || defaultStaticDatePeriod

  const timeGranularity = (getFilterValue({
    key: AvailableFiltersEnum.timeGranularity,
    searchParams,
    prefix: MRR_BREAKDOWN_OVERVIEW_FILTER_PREFIX,
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

    // NOTE: luxon approach is to have "closed" intervals, so we need to subtract one day to get the correct end date
    // Only uses this for week notation that shows the exact day
    // Also, the current week is well formated, so we don't need to subtract one day
    const readableEnd =
      timeGranularity === TimeGranularityEnum.Weekly && index !== intervalData.length - 1
        ? DateTime.fromISO(end).minus({ day: 1 }).toISODate()
        : end
    const foundDataWithSamePeriod = data?.find((d) => d.startOfPeriodDt === start)

    if (foundDataWithSamePeriod) {
      return foundDataWithSamePeriod
    }

    // NOTE: making it a typed const to make sure we don't miss any fields
    const emptyData: MrrDataForOverviewSectionFragment = {
      endOfPeriodDt: readableEnd,
      endingMrr: 0,
      mrrChange: 0,
      mrrChurn: 0,
      mrrContraction: 0,
      mrrExpansion: 0,
      mrrNew: 0,
      startOfPeriodDt: start,
      startingMrr: 0,
    }

    return emptyData
  })

  return paddedData
}

export const formatMrrDataForAreaChart = ({
  data,
  timeGranularity,
  selectedCurrency,
}: {
  data: MrrDataForOverviewSectionFragment[]
  timeGranularity: TimeGranularityEnum
  selectedCurrency: CurrencyEnum
}): AreaChartDataType[] => {
  return data.map((item, index) => ({
    tooltipLabel: `${getItemDateFormatedByTimeGranularity({
      item,
      timeGranularity,
    })}: ${intlFormatNumber(deserializeAmount(item.endingMrr, selectedCurrency), {
      currency: selectedCurrency,
    })}`,
    value: Number(item.endingMrr),
    axisName: intlFormatDateTime(index === 0 ? item.startOfPeriodDt : item.endOfPeriodDt, {
      formatDate: DateFormat.DATE_MED,
    }).date,
  }))
}
