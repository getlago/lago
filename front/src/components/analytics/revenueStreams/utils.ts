import { DateTime, DateTimeUnit, Duration, DurationUnit, Interval } from 'luxon'

import { AvailableFiltersEnum, getFilterValue } from '~/components/designSystem/Filters'
import { REVENUE_STREAMS_OVERVIEW_FILTER_PREFIX } from '~/core/constants/filters'
import {
  RevenueStreamDataForOverviewSectionFragment,
  TimeGranularityEnum,
} from '~/generated/graphql'

const DIFF_CURSOR: Record<TimeGranularityEnum, DurationUnit> = {
  [TimeGranularityEnum.Daily]: 'days',
  [TimeGranularityEnum.Weekly]: 'weeks',
  [TimeGranularityEnum.Monthly]: 'months',
} as const

export const formatRevenueStreamsData = ({
  data,
  searchParams,
  defaultStaticDatePeriod,
  defaultStaticTimeGranularity,
}: {
  data: RevenueStreamDataForOverviewSectionFragment[] | undefined
  searchParams: URLSearchParams
  defaultStaticDatePeriod: string
  defaultStaticTimeGranularity: string
}): RevenueStreamDataForOverviewSectionFragment[] => {
  const datePeriod =
    getFilterValue({
      key: AvailableFiltersEnum.date,
      searchParams,
      prefix: REVENUE_STREAMS_OVERVIEW_FILTER_PREFIX,
    }) || defaultStaticDatePeriod

  const timeGranularity = (getFilterValue({
    key: AvailableFiltersEnum.timeGranularity,
    searchParams,
    prefix: REVENUE_STREAMS_OVERVIEW_FILTER_PREFIX,
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
    const emptyData: RevenueStreamDataForOverviewSectionFragment = {
      commitmentFeeAmountCents: 0,
      couponsAmountCents: 0,
      endOfPeriodDt: readableEnd,
      grossRevenueAmountCents: 0,
      netRevenueAmountCents: 0,
      oneOffFeeAmountCents: 0,
      startOfPeriodDt: start,
      subscriptionFeeAmountCents: 0,
      usageBasedFeeAmountCents: 0,
    }

    return emptyData
  })

  return paddedData
}
