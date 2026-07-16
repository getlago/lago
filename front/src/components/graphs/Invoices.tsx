import { gql } from '@apollo/client'
import { DateTime } from 'luxon'
import { useMemo, useState } from 'react'

import { buildUrlForInvoicesWithFilters } from '~/components/designSystem/Filters'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import ChartHeader from '~/components/designSystem/graphs/ChartHeader'
import { InvoiceCollectionsFakeData } from '~/components/designSystem/graphs/fixtures'
import InlineBarsChart from '~/components/designSystem/graphs/InlineBarsChart'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { ChartWrapper } from '~/components/layouts/Charts'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { Link } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import {
  CurrencyEnum,
  GetInvoiceCollectionsQuery,
  InvoicePaymentStatusTypeEnum,
  useGetInvoiceCollectionsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import ErrorImage from '~/public/images/maneki/error.svg'
import { theme } from '~/styles'
import { tw } from '~/styles/utils'

import {
  AnalyticsPeriodScopeEnum,
  TPeriodScopeTranslationLookupValue,
} from './MonthSelectorDropdown'
import { TGraphProps } from './types'
import { getLastTwelveMonthsNumbersUntilNow, GRAPH_YEAR_MONTH_DATE_FORMAT } from './utils'

const DOT_SIZE = 8

const GRAPH_COLORS = [
  theme.palette.success[400],
  theme.palette.secondary[400],
  theme.palette.grey[300],
]

gql`
  query getInvoiceCollections($currency: CurrencyEnum!) {
    invoiceCollections(currency: $currency) {
      collection {
        paymentStatus
        invoicesCount
        amountCents
        currency
        month
      }
    }
  }
`

export type TInvoiceCollectionsDataResult =
  GetInvoiceCollectionsQuery['invoiceCollections']['collection']

export type TFormatInvoiceCollectionsDataReturn = Map<
  InvoicePaymentStatusTypeEnum,
  TInvoiceCollectionsDataResult
>

const LINE_DATA_ALL_KEY_NAME = 'all'

const lookupInvoiceLineTranslation = {
  [InvoicePaymentStatusTypeEnum.Succeeded]: 'text_6553885df387fd0097fd73a3',
  [InvoicePaymentStatusTypeEnum.Failed]: 'text_6553885df387fd0097fd73a5',
  [InvoicePaymentStatusTypeEnum.Pending]: 'text_6553885df387fd0097fd73a7',
}

export const fillInvoicesDataPerMonthForPaymentStatus = (
  data: TInvoiceCollectionsDataResult | undefined,
  paymentStatus: InvoicePaymentStatusTypeEnum,
  currency: CurrencyEnum,
): TInvoiceCollectionsDataResult => {
  const lastTwelveMonths = getLastTwelveMonthsNumbersUntilNow()
  const res = []

  for (const month of lastTwelveMonths) {
    const existingMonthData = data?.find(
      (d) =>
        d.paymentStatus === paymentStatus &&
        DateTime.fromISO(d.month).toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT) === month,
    )

    if (existingMonthData) {
      res.push({
        ...existingMonthData,
        month: DateTime.fromISO(existingMonthData.month).toFormat(GRAPH_YEAR_MONTH_DATE_FORMAT),
      })
    } else {
      res.push({
        paymentStatus,
        invoicesCount: '0',
        amountCents: '0',
        currency,
        month,
      })
    }
  }

  return res
}

export const formatInvoiceCollectionsData = (
  data: TInvoiceCollectionsDataResult | undefined,
  currency: CurrencyEnum,
): TFormatInvoiceCollectionsDataReturn => {
  const res = new Map()

  res.set(
    InvoicePaymentStatusTypeEnum.Succeeded,
    fillInvoicesDataPerMonthForPaymentStatus(
      data,
      InvoicePaymentStatusTypeEnum.Succeeded,
      currency,
    ),
  )
  res.set(
    InvoicePaymentStatusTypeEnum.Failed,
    fillInvoicesDataPerMonthForPaymentStatus(data, InvoicePaymentStatusTypeEnum.Failed, currency),
  )
  res.set(
    InvoicePaymentStatusTypeEnum.Pending,
    fillInvoicesDataPerMonthForPaymentStatus(data, InvoicePaymentStatusTypeEnum.Pending, currency),
  )

  return res
}

export const extractDataForDisplay = (
  data: TFormatInvoiceCollectionsDataReturn,
): Map<
  InvoicePaymentStatusTypeEnum | typeof LINE_DATA_ALL_KEY_NAME,
  { invoicesCount: number; amountCents: number }
> => {
  const res = new Map()

  const getStatusDataReducer = (
    acc: Pick<TInvoiceCollectionsDataResult[0], 'invoicesCount' | 'amountCents'>,
    curr: { invoicesCount: string; amountCents: string },
  ) => {
    acc.amountCents += Number(curr.amountCents || 0)
    acc.invoicesCount += Number(curr.invoicesCount || 0)

    return acc
  }

  res.set(
    InvoicePaymentStatusTypeEnum.Succeeded,
    data
      .get(InvoicePaymentStatusTypeEnum.Succeeded)
      ?.reduce(getStatusDataReducer, { invoicesCount: 0, amountCents: 0 }),
  )
  res.set(
    InvoicePaymentStatusTypeEnum.Failed,
    data
      .get(InvoicePaymentStatusTypeEnum.Failed)
      ?.reduce(getStatusDataReducer, { invoicesCount: 0, amountCents: 0 }),
  )
  res.set(
    InvoicePaymentStatusTypeEnum.Pending,
    data
      .get(InvoicePaymentStatusTypeEnum.Pending)
      ?.reduce(getStatusDataReducer, { invoicesCount: 0, amountCents: 0 }),
  )
  res.set(LINE_DATA_ALL_KEY_NAME, {
    invoicesCount:
      res.get(InvoicePaymentStatusTypeEnum.Succeeded)?.invoicesCount +
      res.get(InvoicePaymentStatusTypeEnum.Failed)?.invoicesCount +
      res.get(InvoicePaymentStatusTypeEnum.Pending)?.invoicesCount,
    amountCents:
      res.get(InvoicePaymentStatusTypeEnum.Succeeded)?.amountCents +
      res.get(InvoicePaymentStatusTypeEnum.Failed)?.amountCents +
      res.get(InvoicePaymentStatusTypeEnum.Pending)?.amountCents,
  })

  return res
}

export const getAllDataForInvoicesDisplay = ({
  blur,
  currency,
  data,
  demoMode,
  period,
}: {
  blur: boolean
  currency: CurrencyEnum
  data: TInvoiceCollectionsDataResult | undefined
  demoMode: boolean
  period: TPeriodScopeTranslationLookupValue
}) => {
  const paddedData = formatInvoiceCollectionsData(
    demoMode || blur || !data ? InvoiceCollectionsFakeData : data,
    currency,
  )

  if (period === AnalyticsPeriodScopeEnum.Quarter) {
    paddedData.forEach((values, key) => {
      paddedData.set(
        key,
        values.filter((_, index) => index > 8),
      )
    })
  } else if (period === AnalyticsPeriodScopeEnum.Month) {
    paddedData.forEach((values, key) => {
      paddedData.set(
        key,
        values.filter((_, index) => index > 10),
      )
    })
  }

  const [from, to] = [
    paddedData.get(InvoicePaymentStatusTypeEnum.Succeeded)?.[0]?.month,
    paddedData.get(InvoicePaymentStatusTypeEnum.Succeeded)?.[
      (paddedData.get(InvoicePaymentStatusTypeEnum.Succeeded)?.length || 1) - 1
    ]?.month,
  ]
  const extractedData = extractDataForDisplay(paddedData)
  const hasOnlyZeroValues = extractedData.get(LINE_DATA_ALL_KEY_NAME)?.amountCents === 0
  const total =
    (extractedData.get(InvoicePaymentStatusTypeEnum.Failed)?.amountCents || 0) +
    (extractedData.get(InvoicePaymentStatusTypeEnum.Pending)?.amountCents || 0)

  const localBarGraphData = [
    {
      [InvoicePaymentStatusTypeEnum.Succeeded]: hasOnlyZeroValues
        ? 1
        : extractedData.get(InvoicePaymentStatusTypeEnum.Succeeded)?.amountCents || 0,
      [InvoicePaymentStatusTypeEnum.Failed]: hasOnlyZeroValues
        ? 1
        : extractedData.get(InvoicePaymentStatusTypeEnum.Failed)?.amountCents || 0,
      [InvoicePaymentStatusTypeEnum.Pending]: hasOnlyZeroValues
        ? 1
        : extractedData.get(InvoicePaymentStatusTypeEnum.Pending)?.amountCents || 0,
    },
  ]

  return {
    barGraphData: localBarGraphData,
    dateFrom: from,
    dateTo: to,
    lineData: extractedData,
    totalAmount: total,
  }
}

const Invoices = ({
  demoMode = false,
  currency = CurrencyEnum.Usd,
  period,
  className,
  blur = false,
  forceLoading,
}: TGraphProps) => {
  const { translate } = useInternationalization()
  const [hoveredBarId, setHoveredBarId] = useState<string | undefined>(undefined)
  const { data, loading, error } = useGetInvoiceCollectionsQuery({
    variables: {
      currency,
    },
    skip: demoMode || blur || !currency,
  })
  const isLoading = forceLoading || loading

  const { barGraphData, dateFrom, dateTo, lineData, totalAmount } = useMemo(() => {
    return getAllDataForInvoicesDisplay({
      data: data?.invoiceCollections.collection,
      currency,
      demoMode,
      blur,
      period,
    })
  }, [blur, currency, data?.invoiceCollections.collection, demoMode, period])

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
            name={translate('text_6553885df387fd0097fd73a0')}
            tooltipText={translate('text_65562f85ed468200b9debb88')}
            amount={intlFormatNumber(deserializeAmount(totalAmount, currency), {
              currency,
            })}
            period={translate('text_633dae57ca9a923dd53c2097', {
              fromDate: dateFrom,
              toDate: dateTo,
            })}
            blur={blur}
            loading={isLoading}
          />

          <ChartWrapper blur={blur}>
            <div className="flex flex-col gap-4">
              {!!isLoading ? (
                <>
                  <Skeleton variant="text" />

                  <div>
                    {[...Array(3)].map((_, index) => (
                      <div
                        key={`invoices-skeleton-${index}`}
                        className="flex h-10 flex-1 items-center gap-2 shadow-b"
                      >
                        <Skeleton variant="circular" size="tiny" />
                        <Skeleton className="w-[32%]" variant="text" />
                        <Skeleton className="ml-auto w-[32%]" variant="text" />
                      </div>
                    ))}
                  </div>
                </>
              ) : (
                <>
                  <InlineBarsChart
                    data={barGraphData}
                    colors={GRAPH_COLORS}
                    hoveredBarId={hoveredBarId}
                  />
                  <div>
                    {[
                      InvoicePaymentStatusTypeEnum.Succeeded,
                      InvoicePaymentStatusTypeEnum.Failed,
                      InvoicePaymentStatusTypeEnum.Pending,
                    ].map((status, index) => {
                      const linkParams = new URLSearchParams()

                      linkParams.set('paymentStatus', status)

                      return (
                        <Link
                          className="hover:no-underline focus:ring-0 focus-visible:ring-0"
                          to={buildUrlForInvoicesWithFilters(linkParams)}
                          key={`invoices-item-${status}-${index}`}
                        >
                          <div
                            className="flex h-10 items-center gap-2 shadow-b hover:bg-grey-100"
                            onMouseEnter={() => setHoveredBarId(status)}
                            onMouseLeave={() => setHoveredBarId(undefined)}
                          >
                            <svg height={DOT_SIZE} width={DOT_SIZE}>
                              <circle cx="4" cy="4" r="4" fill={GRAPH_COLORS[index]} />
                            </svg>
                            <Typography variant="caption" color="grey700">
                              {translate(lookupInvoiceLineTranslation[status], {
                                count: lineData.get(status)?.invoicesCount,
                              })}
                            </Typography>
                            <Typography className="ml-auto" variant="caption" color="grey600">
                              {intlFormatNumber(
                                deserializeAmount(lineData.get(status)?.amountCents || 0, currency),
                                { currency },
                              )}
                            </Typography>
                          </div>
                        </Link>
                      )
                    })}

                    <div className="flex h-10 items-center gap-2">
                      <svg height={DOT_SIZE} width={DOT_SIZE}></svg>
                      <Typography variant="caption" color="grey700">
                        {translate('text_6553885df387fd0097fd73a9', {
                          count: lineData.get(LINE_DATA_ALL_KEY_NAME)?.invoicesCount,
                        })}
                      </Typography>
                      <Typography className="ml-auto" variant="caption" color="grey600">
                        {intlFormatNumber(
                          deserializeAmount(
                            lineData.get(LINE_DATA_ALL_KEY_NAME)?.amountCents || 0,
                            currency,
                          ),
                          {
                            currency,
                          },
                        )}
                      </Typography>
                    </div>
                  </div>
                </>
              )}
            </div>
          </ChartWrapper>
        </>
      )}
    </div>
  )
}

export default Invoices
