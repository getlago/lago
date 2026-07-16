import { Icon } from 'lago-design-system'
import _groupBy from 'lodash/groupBy'
import { useMemo } from 'react'
import { generatePath, useSearchParams } from 'react-router-dom'

import { AnalyticsStateProvider } from '~/components/analytics/AnalyticsStateContext'
import { formatUsageData } from '~/components/analytics/usage/utils'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import StackedBarChart from '~/components/designSystem/graphs/StackedBarChart'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { ANALYTIC_USAGE_BILLABLE_METRIC_ROUTE, Link } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum, DataApiUsage, TimeGranularityEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import EmptyImage from '~/public/images/maneki/empty.svg'
import ErrorImage from '~/public/images/maneki/error.svg'
import { theme } from '~/styles'

type UsageBreakdownBillableMetricsProps = {
  data?: DataApiUsage[]
  defaultStaticDatePeriod: string
  defaultStaticTimeGranularity: TimeGranularityEnum
  selectedCurrency: CurrencyEnum
  filtersPrefix: string
  loading: boolean
  valueKey: 'units' | 'amountCents'
  displayFormat?: (value: string | number, currency: CurrencyEnum) => string
  hasError: boolean
}

const UsageBreakdownBillableMetrics = ({
  data,
  defaultStaticDatePeriod,
  defaultStaticTimeGranularity,
  selectedCurrency,
  filtersPrefix,
  loading,
  valueKey,
  displayFormat,
  hasError,
}: UsageBreakdownBillableMetricsProps) => {
  const { translate } = useInternationalization()
  const [searchParams] = useSearchParams()

  const { grouped, totals } = useMemo(() => {
    if (!data) {
      return {
        grouped: {},
        totals: {},
      }
    }

    const groups = _groupBy(data, (item) => item.billableMetricCode)
    const _totals: Record<string, number> = {}

    Object.keys(groups).forEach((key) => {
      const formatted = formatUsageData({
        searchParams,
        data: groups[key],
        defaultStaticDatePeriod,
        defaultStaticTimeGranularity,
        filtersPrefix,
      })

      groups[key] = formatted as DataApiUsage[]

      _totals[key] = formatted.reduce((p, c) => p + Number(c[valueKey]), 0) || 0

      return groups
    })

    return {
      grouped: groups,
      totals: _totals,
    }
  }, [
    data,
    defaultStaticDatePeriod,
    defaultStaticTimeGranularity,
    filtersPrefix,
    searchParams,
    valueKey,
  ])

  if (hasError) {
    return (
      <GenericPlaceholder
        className="pt-12"
        title={translate('text_634812d6f16b31ce5cbf4126')}
        subtitle={translate('text_634812d6f16b31ce5cbf4128')}
        buttonTitle={translate('text_634812d6f16b31ce5cbf412a')}
        buttonVariant="primary"
        buttonAction={() => location.reload()}
        image={<ErrorImage width="136" height="104" />}
      />
    )
  }

  if (loading) {
    return (
      <div className="mt-6 grid grid-cols-2 gap-6">
        {[0, 1, 2, 3].map((i) => (
          <div
            className="flex flex-col gap-2"
            key={`usage-breakdown-billable-metrics-loading-${i}`}
          >
            <Skeleton variant="text" className="w-20" />
            <Skeleton variant="text" className="w-40" />
            <Skeleton variant="text" className="w-40" />
            <Skeleton variant="text" className="w-40" />
          </div>
        ))}
      </div>
    )
  }

  if (!loading && !data?.length) {
    return (
      <GenericPlaceholder
        className="pt-12"
        title={translate('text_1747819375043rmg1hu54ul7')}
        subtitle={translate('text_1747820933511hc5y0fv9pae')}
        image={<EmptyImage width="136" height="104" />}
      />
    )
  }

  return (
    <div className="mt-6 grid grid-cols-2 gap-6">
      {Object.keys(grouped || {}).map((key) => (
        <div className="flex flex-col gap-6" key={`usage-breakdown-billable-metric-${key}`}>
          <div className="flex flex-col gap-1">
            <Link
              to={generatePath(ANALYTIC_USAGE_BILLABLE_METRIC_ROUTE, {
                billableMetricCode: key,
              })}
            >
              <div className="flex cursor-pointer items-center gap-1">
                <Typography variant="bodyHl" color="grey700">
                  {key}
                </Typography>

                <Icon name="chevron-right" size="small" />
              </div>
            </Link>

            <Typography variant="body" color="grey700">
              {displayFormat?.(totals[key], selectedCurrency) ||
                intlFormatNumber(deserializeAmount(totals[key], selectedCurrency), {
                  currency: selectedCurrency,
                })}
            </Typography>
          </div>

          <AnalyticsStateProvider>
            <StackedBarChart
              margin={{
                right: 32,
              }}
              customFormatter={displayFormat}
              xAxisDataKey="startOfPeriodDt"
              xAxisTickAttributes={['startOfPeriodDt', 'endOfPeriodDt']}
              currency={selectedCurrency}
              data={grouped[key]}
              loading={loading}
              timeGranularity={defaultStaticTimeGranularity}
              inlineTooltip={true}
              bars={[
                {
                  tooltipIndex: 0,
                  barIndex: 0,
                  dataKey: valueKey,
                  colorHex: theme.palette.primary[500],
                  tooltipLabel: translate('text_1746541426463wcwfuryd12g'),
                },
              ]}
            />
          </AnalyticsStateProvider>
        </div>
      ))}
    </div>
  )
}

export default UsageBreakdownBillableMetrics
