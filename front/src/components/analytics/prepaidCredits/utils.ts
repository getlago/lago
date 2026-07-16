import { DateTime, DateTimeUnit, Duration, DurationUnit, Interval } from 'luxon'

import { AvailableFiltersEnum, getFilterValue } from '~/components/designSystem/Filters'
import { PREPAID_CREDITS_OVERVIEW_FILTER_PREFIX } from '~/core/constants/filters'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { getCurrencyPrecision } from '~/core/serializers/serializeAmount'
import {
  CurrencyEnum,
  PrepaidCreditsDataForOverviewSectionFragment,
  TimeGranularityEnum,
} from '~/generated/graphql'

const DIFF_CURSOR: Record<TimeGranularityEnum, DurationUnit> = {
  [TimeGranularityEnum.Daily]: 'days',
  [TimeGranularityEnum.Weekly]: 'weeks',
  [TimeGranularityEnum.Monthly]: 'months',
} as const

export const toAmountCents = (amount: number, currency: CurrencyEnum): string => {
  return intlFormatNumber(amount, {
    currency,
    style: 'currency',
    currencyDisplay: 'symbol',
    minimumFractionDigits: getCurrencyPrecision(currency),
  })
}

export const formatPrepaidCreditsData = ({
  data,
  searchParams,
  defaultStaticDatePeriod,
  defaultStaticTimeGranularity,
  currency,
}: {
  data: PrepaidCreditsDataForOverviewSectionFragment[] | undefined
  searchParams: URLSearchParams
  defaultStaticDatePeriod: string
  defaultStaticTimeGranularity: string
  currency: CurrencyEnum
}): PrepaidCreditsDataForOverviewSectionFragment[] => {
  const datePeriod =
    getFilterValue({
      key: AvailableFiltersEnum.date,
      searchParams,
      prefix: PREPAID_CREDITS_OVERVIEW_FILTER_PREFIX,
    }) || defaultStaticDatePeriod

  const timeGranularity = (getFilterValue({
    key: AvailableFiltersEnum.timeGranularity,
    searchParams,
    prefix: PREPAID_CREDITS_OVERVIEW_FILTER_PREFIX,
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

    const emptyData: PrepaidCreditsDataForOverviewSectionFragment = {
      endOfPeriodDt: readableEnd,
      startOfPeriodDt: start,
      amountCurrency: currency,
      consumedAmount: 0,
      consumedCreditsQuantity: 0,
      offeredAmount: 0,
      offeredCreditsQuantity: 0,
      purchasedAmount: 0,
      purchasedCreditsQuantity: 0,
      voidedAmount: 0,
      voidedCreditsQuantity: 0,
    }

    return emptyData
  })

  return paddedData.map((item) => ({
    ...item,
    consumedAmount: Number(item.consumedAmount) === 0 ? 0 : -item.consumedAmount,
    voidedAmount: Number(item.voidedAmount) === 0 ? 0 : -item.voidedAmount,
    offeredAmount: item.offeredAmount,
    purchasedAmount: item.purchasedAmount,
  }))
}
