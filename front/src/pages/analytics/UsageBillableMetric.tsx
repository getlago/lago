import { tw } from 'lago-design-system'
import { useState } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { AnalyticsStateProvider } from '~/components/analytics/AnalyticsStateContext'
import { UsageBreakdownType } from '~/components/analytics/usage/types'
import { useUsageAnalyticsBillableMetric } from '~/components/analytics/usage/useUsageAnalyticsBillableMetric'
import { Button } from '~/components/designSystem/Button'
import {
  AvailableQuickFilters,
  Filters,
  UsageBillableMetricAvailableFilters,
} from '~/components/designSystem/Filters'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import StackedBarChart from '~/components/designSystem/graphs/StackedBarChart'
import { getItemDateFormatedByTimeGranularity } from '~/components/designSystem/graphs/utils'
import { HorizontalDataTable } from '~/components/designSystem/Table/HorizontalDataTable'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { PageBannerHeaderWithBurgerMenu } from '~/components/layouts/CenteredPage'
import { FullscreenPage } from '~/components/layouts/FullscreenPage'
import { ANALYTICS_USAGE_BILLABLE_METRIC_FILTER_PREFIX } from '~/core/constants/filters'
import { NewAnalyticsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { ANALYTIC_TABS_ROUTE, useNavigate } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum, TimeGranularityEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import ErrorImage from '~/public/images/maneki/error.svg'
import { theme } from '~/styles'

const TRANSLATIONS_MAP: Record<UsageBreakdownType, string> = {
  [UsageBreakdownType.Units]: 'text_17465414264637hzft31ck6c',
  [UsageBreakdownType.Amount]: 'text_1746541426463wcwfuryd12g',
}

type AmountCellProps = {
  value: number
  currency: CurrencyEnum
  displayFormat?: (value: string | number, currency: CurrencyEnum) => string
}

const AmountCell = ({ value, currency, displayFormat }: AmountCellProps) => {
  return (
    <Typography
      variant="body"
      className={tw({
        'text-green-600': value > 0,
        'text-grey-500': Number(value) === 0,
        'text-red-600': value < 0,
      })}
    >
      {displayFormat?.(value, currency) ||
        intlFormatNumber(deserializeAmount(value, currency), {
          currencyDisplay: 'symbol',
          currency,
        })}
    </Typography>
  )
}

const UsageBillableMetric = () => {
  const { translate } = useInternationalization()
  const { open: openPremiumWarningDialog } = usePremiumWarningDialog()
  const navigate = useNavigate()

  const { billableMetricCode } = useParams()

  const [breakdownType, setBreakdownType] = useState<UsageBreakdownType>(UsageBreakdownType.Units)

  const {
    selectedCurrency,
    defaultCurrency,
    hasError,
    isLoading,
    total,
    getDefaultStaticDateFilter,
    getDefaultStaticTimeGranularityFilter,
    hasAccessToAnalyticsDashboardsFeature,
    timeGranularity,
    data,
    valueKey,
    displayFormat,
  } = useUsageAnalyticsBillableMetric({
    billableMetricCode: billableMetricCode as string,
    breakdownType,
  })

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

  return (
    <>
      <PageBannerHeaderWithBurgerMenu>
        <div className="flex items-center gap-2">
          <Button
            variant="quaternary"
            icon="arrow-left"
            onClick={() => {
              navigate(
                generatePath(ANALYTIC_TABS_ROUTE, {
                  tab: NewAnalyticsTabsOptionsEnum.usage,
                }),
              )
            }}
          />

          <Typography variant="bodyHl" color="grey700">
            {billableMetricCode}
          </Typography>
        </div>
      </PageBannerHeaderWithBurgerMenu>

      <FullscreenPage.Wrapper>
        <div className="flex flex-col gap-6">
          <Filters.Provider
            filtersNamePrefix={ANALYTICS_USAGE_BILLABLE_METRIC_FILTER_PREFIX}
            staticFilters={{
              currency: defaultCurrency,
              date: getDefaultStaticDateFilter(),
            }}
            staticQuickFilters={{
              timeGranularity: getDefaultStaticTimeGranularityFilter(),
            }}
            availableFilters={UsageBillableMetricAvailableFilters}
            quickFiltersType={AvailableQuickFilters.timeGranularity}
            buttonOpener={({ onClick }) => (
              <Button
                startIcon="filter"
                endIcon={!hasAccessToAnalyticsDashboardsFeature ? 'sparkles' : undefined}
                size="small"
                variant="quaternary"
                onClick={(e) => {
                  if (!hasAccessToAnalyticsDashboardsFeature) {
                    e.stopPropagation()
                    openPremiumWarningDialog()
                  } else {
                    onClick()
                  }
                }}
              >
                {translate('text_66ab42d4ece7e6b7078993ad')}
              </Button>
            )}
          >
            <div className="flex items-center justify-between">
              <Typography variant="subhead1" color="grey700">
                {billableMetricCode}
              </Typography>

              <div className="flex justify-end">
                <div className="flex gap-4">
                  <Filters.QuickFilters />

                  <div className="h-full w-1 bg-grey-300"></div>

                  <div className="flex gap-1">
                    {[UsageBreakdownType.Units, UsageBreakdownType.Amount].map(
                      (_breakdownType, index) => (
                        <Button
                          key={`usage-breakdown-section-${index}`}
                          variant={_breakdownType === breakdownType ? 'secondary' : 'quaternary'}
                          onClick={() => setBreakdownType(_breakdownType)}
                          size="small"
                        >
                          {translate(TRANSLATIONS_MAP[_breakdownType])}
                        </Button>
                      ),
                    )}
                  </div>
                </div>
              </div>
            </div>

            <Filters.Component />
          </Filters.Provider>

          <div>
            <Typography variant="headline" color="grey700" className="mb-2">
              {displayFormat?.(total, selectedCurrency) ||
                intlFormatNumber(deserializeAmount(total || 0, selectedCurrency), {
                  currencyDisplay: 'symbol',
                  currency: selectedCurrency,
                })}
            </Typography>

            <AnalyticsStateProvider>
              <div className="flex flex-col gap-6">
                <StackedBarChart
                  margin={{
                    right: 32,
                  }}
                  xAxisDataKey="startOfPeriodDt"
                  xAxisTickAttributes={['startOfPeriodDt', 'endOfPeriodDt']}
                  currency={selectedCurrency}
                  data={data}
                  loading={isLoading}
                  timeGranularity={timeGranularity}
                  bars={[
                    {
                      tooltipIndex: 0,
                      barIndex: 0,
                      dataKey: valueKey,
                      colorHex: theme.palette.primary[500],
                      tooltipLabel: translate('text_1746541426463wcwfuryd12g'),
                    },
                  ]}
                  customFormatter={displayFormat}
                  inlineTooltip={true}
                />

                <HorizontalDataTable
                  leftColumnWidth={190}
                  columnWidth={timeGranularity === TimeGranularityEnum.Monthly ? 180 : 228}
                  data={data}
                  loading={isLoading}
                  rows={[
                    {
                      key: 'startOfPeriodDt',
                      type: 'header',
                      label: translate('text_1739268382272qnne2h7slna'),
                      content: (item) => {
                        return (
                          <Typography variant="captionHl">
                            {getItemDateFormatedByTimeGranularity({ item, timeGranularity })}
                          </Typography>
                        )
                      },
                    },
                    {
                      key: 'amountCents',
                      type: 'data',
                      label: billableMetricCode,
                      content: (item) => (
                        <AmountCell
                          value={item[valueKey]}
                          currency={selectedCurrency}
                          displayFormat={displayFormat}
                        />
                      ),
                    },
                  ]}
                />
              </div>
            </AnalyticsStateProvider>
          </div>
        </div>
      </FullscreenPage.Wrapper>
    </>
  )
}

export default UsageBillableMetric

/*
TODO: The logic below will be used to display billable metric filters when they will be available from the backend

const RowLabel = ({ label, color }: { label: string; color: string }) => (
  <div className="flex items-center gap-2">
    <div className="size-3 rounded-full" style={{ backgroundColor: color }} />

    <Typography variant="bodyHl" color="grey700">{label}</Typography>
  </div>
)

  const FAKE_FILTERS = [
    { key: 'storageUS', values: ['eminem'], __typename: 'BillableMetricFilter' },
    { key: 'storageEU', values: ['eminem'], __typename: 'BillableMetricFilter' },
    { key: 'storageAsia', values: ['world'], __typename: 'BillableMetricFilter' },
    { key: 'storageAfrica', values: ['hello', 'test'], __typename: 'BillableMetricFilter' },
  ]

  const filters = FAKE_FILTERS

  const data =
    xData?.map((i) => {
      const x = { ...i }

      filters.forEach((f) => {
        x[`amount_${f.key}`] = random(0, 20000)
      })

      return x
    }) || []

  const colors = [
    'rgba(0, 80, 184, 1)',
    'rgba(19, 102, 208, 1)',
    'rgba(38, 125, 255, 1)',
    'rgba(57, 140, 255, 1)',
    'rgba(76, 154, 255, 1)',
    'rgba(102, 170, 255, 1)',
    'rgba(128, 186, 255, 1)',
    'rgba(153, 198, 255, 1)',
    'rgba(179, 212, 255, 1)',
    'rgba(191, 215, 250, 1)',
    'rgba(204, 219, 245, 1)',
    'rgba(210, 221, 240, 1)',
    'rgba(215, 222, 235, 1)',
    'rgba(217, 222, 231, 1)',
    'rgba(220, 224, 229, 1)',
  ]

  const getColor = (index: number) => colors[index] ?? colors[colors.length - 1]

  const bars = filters.map((filter, index) => ({
    dataKey: `amount_${filter.key}`,
    colorHex: getColor(index),
    tooltipLabel: filter.key,
  }))

  const rows = filters.map((filter, index) => ({
    key: filter.key,
    type: 'data',
    label: <RowLabel label={filter.key} color={getColor(index)} />,
    content: (item) => (
      <AmountCell value={item[`amount_${filter.key}`]} currency={selectedCurrency} />
    ),
  }))

*/
