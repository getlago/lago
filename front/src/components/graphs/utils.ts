import { DateTime } from 'luxon'

import { AreaChartDataType } from '~/components/designSystem/graphs/types'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum } from '~/generated/graphql'

export const GRAPH_YEAR_MONTH_DATE_FORMAT = 'LLL. yyyy'

export type TAreaChartDataResult = {
  amountCents: string | number
  currency?: CurrencyEnum | null | undefined
  month: string | null
}[]

export const getLastTwelveMonthsNumbersUntilNow = () => {
  const monthsNumberList = []
  let cursor = DateTime.now().startOf('month')

  while (monthsNumberList.length < 13) {
    monthsNumberList.unshift(cursor.toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT))
    cursor = cursor.minus({ month: 1 })
  }

  return monthsNumberList
}

export const padAndTransformDataOverLastTwelveMonth = (
  data: TAreaChartDataResult,
  currency: CurrencyEnum,
) => {
  const monthsArray = getLastTwelveMonthsNumbersUntilNow()

  // Analytics endpoints can emit multiple rows per calendar month when results
  // are split across billing entities, so sum amountCents per month before
  // mapping onto the chart axis.
  const totalsByMonth = data.reduce<
    Record<string, { amountCents: number; currency?: CurrencyEnum | null }>
  >((acc, item) => {
    const key = DateTime.fromISO(item.month as string).toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT)

    acc[key] = {
      amountCents: (acc[key]?.amountCents ?? 0) + Number(item.amountCents),
      currency: acc[key]?.currency ?? item.currency,
    }

    return acc
  }, {})

  return monthsArray.map((month) => {
    const aggregated = totalsByMonth[month]

    return aggregated
      ? { month, amountCents: aggregated.amountCents, currency: aggregated.currency }
      : { currency, month, amountCents: 0 }
  })
}

export const formatDataForAreaChart = (
  data: TAreaChartDataResult,
  currency: CurrencyEnum,
): AreaChartDataType[] => {
  data = padAndTransformDataOverLastTwelveMonth(data, currency)

  return data?.map((item: TAreaChartDataResult[0]) => ({
    tooltipLabel: `${item.month}: ${intlFormatNumber(
      deserializeAmount(item.amountCents, item.currency || CurrencyEnum.Usd),
      {
        currency: item.currency as CurrencyEnum,
      },
    )}`,
    value: Number(item.amountCents),
    axisName: item.month as string,
  }))
}
