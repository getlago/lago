import { gql } from '@apollo/client'
import { useMemo } from 'react'

import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import AreaChart from '~/components/designSystem/graphs/AreaChart'
import ChartHeader from '~/components/designSystem/graphs/ChartHeader'
import { AreaGrossRevenuesChartFakeData } from '~/components/designSystem/graphs/fixtures'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum, GetGrossRevenuesQuery, useGetGrossRevenuesQuery } from '~/generated/graphql'
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
  query getGrossRevenues(
    $currency: CurrencyEnum!
    $externalCustomerId: String
    $months: Int
    $billingEntityId: ID
  ) {
    grossRevenues(
      currency: $currency
      externalCustomerId: $externalCustomerId
      months: $months
      billingEntityId: $billingEntityId
    ) {
      collection {
        amountCents
        currency
        month
      }
    }
  }
`

export function getAllDataForGrossDisplay({
  data,
  currency,
  demoMode,
  blur,
  period,
}: {
  data?: GetGrossRevenuesQuery['grossRevenues']['collection']
  currency: CurrencyEnum
  demoMode: boolean
  blur: boolean
  period: TPeriodScopeTranslationLookupValue
}) {
  const formatedData = formatDataForAreaChart(
    demoMode || blur || !data ? AreaGrossRevenuesChartFakeData : (data as TAreaChartDataResult),
    currency,
  )

  if (period === AnalyticsPeriodScopeEnum.Quarter) {
    formatedData.splice(0, 9)
  } else if (period === AnalyticsPeriodScopeEnum.Month) {
    formatedData.splice(0, 11)
  }

  const sum = formatedData.reduce((acc, curr) => acc + Number(curr.value), 0)
  const [from, to] = [formatedData[0].axisName, formatedData[formatedData.length - 1].axisName]

  return { dataForAreaChart: formatedData, amountSum: sum, dateFrom: from, dateTo: to }
}

const Gross = ({
  blur = false,
  className,
  currency = CurrencyEnum.Usd,
  demoMode = false,
  period,
  externalCustomerId,
  billingEntityId,
}: TGraphProps & { externalCustomerId?: string; billingEntityId?: string }) => {
  const { translate } = useInternationalization()
  const { data, loading, error } = useGetGrossRevenuesQuery({
    variables: {
      currency: currency,
      externalCustomerId: externalCustomerId,
      months: 12,
      billingEntityId: billingEntityId || undefined,
    },
    skip: demoMode || blur || !currency,
  })

  const { dataForAreaChart, amountSum, dateFrom, dateTo } = useMemo(() => {
    return getAllDataForGrossDisplay({
      data: data?.grossRevenues?.collection,
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
            name={translate('text_6553885df387fd0097fd7385')}
            tooltipText={
              externalCustomerId
                ? translate('text_65564e8e4af2340050d431bf')
                : translate('text_65562f85ed468200b9debb53')
            }
            amount={intlFormatNumber(deserializeAmount(amountSum, currency), {
              currency: currency,
            })}
            period={translate('text_633dae57ca9a923dd53c2097', {
              fromDate: dateFrom,
              toDate: dateTo,
            })}
            loading={loading}
            blur={blur}
          />
          <AreaChart
            loading={loading}
            blur={blur}
            data={dataForAreaChart}
            hasOnlyZeroValues={amountSum === 0}
            currency={currency}
          />
        </>
      )}
    </div>
  )
}

export default Gross
