import { gql } from '@apollo/client'
import { Icon } from 'lago-design-system'
import { DateTime } from 'luxon'
import { FC } from 'react'

import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import {
  AnalyticsPeriodScopeEnum,
  TPeriodScopeTranslationLookupValue,
} from '~/components/graphs/MonthSelectorDropdown'
import { TGraphProps } from '~/components/graphs/types'
import { GRAPH_YEAR_MONTH_DATE_FORMAT } from '~/components/graphs/utils'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum, useGetOverdueQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import ErrorImage from '~/public/images/maneki/error.svg'

gql`
  query getOverdue($currency: CurrencyEnum!, $externalCustomerId: String, $months: Int!) {
    overdueBalances(currency: $currency, externalCustomerId: $externalCustomerId, months: $months) {
      collection {
        amountCents
        currency
        month
        lagoInvoiceIds
      }
    }
  }
`

const getDatesFromPeriod = (period: TPeriodScopeTranslationLookupValue) => {
  let from = DateTime.now()
  let month = 12

  if (period === AnalyticsPeriodScopeEnum.Year) {
    from = DateTime.now().minus({ years: 1 })
  } else if (period === AnalyticsPeriodScopeEnum.Quarter) {
    from = DateTime.now().minus({ months: 3 })
    month = from.month
  } else if (period === AnalyticsPeriodScopeEnum.Month) {
    from = DateTime.now().minus({ months: 1 })
    month = from.month
  }

  return {
    from: from.toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
    to: DateTime.now().toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
    month,
  }
}

const Overview: FC<TGraphProps & { externalCustomerId?: string }> = ({
  currency = CurrencyEnum.Usd,
  period,
  externalCustomerId,
}) => {
  const { translate } = useInternationalization()
  const { from, to, month } = getDatesFromPeriod(period)
  const { data, loading, error } = useGetOverdueQuery({
    variables: { currency: currency, externalCustomerId: externalCustomerId, months: 12 },
    skip: !currency,
  })

  const overdueData = data?.overdueBalances.collection.reduce<{
    amountCents: number
    invoiceCount: number
  }>(
    (acc, item) => {
      const itemMonth = DateTime.fromISO(item.month as string).month

      // If the period is month and the item month is different from the period month, we should not count it
      if (period === AnalyticsPeriodScopeEnum.Month && itemMonth !== month) {
        return acc
      }

      const formattedAmountCents = deserializeAmount(item.amountCents, item.currency)

      return {
        amountCents: acc.amountCents + formattedAmountCents,
        invoiceCount: acc.invoiceCount + item.lagoInvoiceIds.length,
      }
    },
    {
      amountCents: 0,
      invoiceCount: 0,
    },
  )

  return (
    <div className="col-[span_1] bg-white pb-6 lg:col-[span_2]">
      {!!error && !loading && (
        <GenericPlaceholder
          title={translate('text_636d023ce11a9d038819b579')}
          subtitle={translate('text_636d023ce11a9d038819b57b')}
          image={<ErrorImage width="136" height="104" />}
        />
      )}
      {!!loading && !error && (
        <div className="flex h-14 flex-col gap-5">
          <Skeleton variant="text" className="w-25" />
          <Skeleton variant="text" className="w-75" />
        </div>
      )}
      {!loading && !error && (
        <div className="flex flex-col gap-2">
          <div className="flex flex-row items-center justify-between">
            <div className="flex flex-row items-center gap-2">
              <Typography variant="captionHl">
                {translate('text_6670a6577ecbf200898af647')}
              </Typography>
              <Tooltip title={translate('text_6670a6577ecbf200898af646')} placement="top-start">
                <Icon name="info-circle" />
              </Tooltip>
            </div>
            <Typography variant="note" color="grey600">
              {translate('text_633dae57ca9a923dd53c2097', {
                fromDate: from,
                toDate: to,
              })}
            </Typography>
          </div>
          <Typography variant="subhead1">
            {intlFormatNumber(overdueData?.amountCents || 0, {
              currency,
            })}
            <Typography className="ml-1" variant="caption" component="span">
              {translate(
                'text_6670a6577ecbf200898af64a',
                { count: overdueData?.invoiceCount },
                overdueData?.invoiceCount,
              )}
            </Typography>
          </Typography>
        </div>
      )}
    </div>
  )
}

export default Overview
