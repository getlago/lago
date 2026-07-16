import { gql } from '@apollo/client'
import { useMemo } from 'react'

import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import AreaChart from '~/components/designSystem/graphs/AreaChart'
import ChartHeader from '~/components/designSystem/graphs/ChartHeader'
import { AreaMrrChartFakeData } from '~/components/designSystem/graphs/fixtures'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum, GetMrrQuery, useGetMrrQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import ErrorImage from '~/public/images/maneki/error.svg'
import { tw } from '~/styles/utils'

import {
  AnalyticsPeriodScopeEnum,
  TPeriodScopeTranslationLookupValue,
} from './MonthSelectorDropdown'
import { TGraphProps } from './types'
import { formatDataForAreaChart, TAreaChartDataResult } from './utils'

gql`
  query getMrr($currency: CurrencyEnum!) {
    mrrs(currency: $currency) {
      collection {
        amountCents
        currency
        month
      }
    }
  }
`

export function getAllDataForMrrDisplay({
  data,
  currency,
  demoMode,
  blur,
  period,
}: {
  data?: GetMrrQuery['mrrs']['collection']
  currency: CurrencyEnum
  demoMode: boolean
  blur: boolean
  forceLoading?: boolean
  period: TPeriodScopeTranslationLookupValue
}) {
  const formatedData = formatDataForAreaChart(
    demoMode || blur || !data ? AreaMrrChartFakeData : (data as TAreaChartDataResult),
    currency,
  )

  if (period === AnalyticsPeriodScopeEnum.Quarter) {
    formatedData.splice(0, 9)
  } else if (period === AnalyticsPeriodScopeEnum.Month) {
    formatedData.splice(0, 11)
  }

  const lastMrr = formatedData[formatedData.length - 2].value || 0
  const [dateFrom, dateTo] = [
    formatedData[0].axisName,
    formatedData[formatedData.length - 1].axisName,
  ]

  return {
    hasOnlyZeroValues: formatedData.reduce((acc, curr) => acc + Number(curr.value), 0) === 0,
    dataForAreaChart: formatedData,
    lastMonthMrr: lastMrr,
    dateFrom,
    dateTo,
  }
}

const Mrr = ({
  blur = false,
  className,
  currency = CurrencyEnum.Usd,
  demoMode = false,
  period,
  forceLoading,
}: TGraphProps) => {
  const { translate } = useInternationalization()
  const { data, loading, error } = useGetMrrQuery({
    variables: { currency: currency },
    skip: demoMode || blur || !currency,
  })
  const isLoading = loading || forceLoading

  const { dataForAreaChart, lastMonthMrr, dateFrom, dateTo, hasOnlyZeroValues } = useMemo(() => {
    return getAllDataForMrrDisplay({
      data: data?.mrrs?.collection,
      currency,
      demoMode,
      blur,
      period,
    })
  }, [data, currency, demoMode, blur, period])

  return (
    <div className={tw('flex flex-col gap-6 bg-white px-0 py-6', className)}>
      {!!error ? (
        <GenericPlaceholder
          className="m-0 p-0"
          title={translate('text_636d023ce11a9d038819b579')}
          subtitle={translate('text_636d023ce11a9d038819b57b')}
          image={<ErrorImage width="136" height="104" />}
        />
      ) : (
        <>
          <ChartHeader
            name={translate('text_6553885df387fd0097fd738c')}
            tooltipText={translate('text_655b21068fc7f80067fd6315')}
            amount={intlFormatNumber(deserializeAmount(lastMonthMrr, currency), {
              currency: currency,
            })}
            period={translate('text_633dae57ca9a923dd53c2097', {
              fromDate: dateFrom,
              toDate: dateTo,
            })}
            loading={isLoading}
            blur={blur}
          />
          <AreaChart
            loading={isLoading}
            blur={blur}
            data={dataForAreaChart}
            hasOnlyZeroValues={hasOnlyZeroValues}
            currency={currency}
          />
        </>
      )}
    </div>
  )
}

export default Mrr
