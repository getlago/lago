import { gql } from '@apollo/client'

import { AnalyticsStateProvider } from '~/components/analytics/AnalyticsStateContext'
import { usePrepaidCreditsAnalyticsOverview } from '~/components/analytics/prepaidCredits/usePrepaidCreditsAnalyticsOverview'
import { toAmountCents } from '~/components/analytics/prepaidCredits/utils'
import { Button } from '~/components/designSystem/Button'
import {
  AvailableQuickFilters,
  Filters,
  PrepaidCreditsOverviewAvailableFilters,
} from '~/components/designSystem/Filters'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import StackedBarChart from '~/components/designSystem/graphs/StackedBarChart'
import { getItemDateFormatedByTimeGranularity } from '~/components/designSystem/graphs/utils'
import { HorizontalDataTable } from '~/components/designSystem/Table/HorizontalDataTable'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { PREPAID_CREDITS_OVERVIEW_FILTER_PREFIX } from '~/core/constants/filters'
import { CurrencyEnum, TimeGranularityEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import ErrorImage from '~/public/images/maneki/error.svg'
import { tw } from '~/styles/utils'

gql`
  fragment PrepaidCreditsDataForOverviewSection on DataApiPrepaidCredit {
    amountCurrency
    consumedAmount
    consumedCreditsQuantity
    endOfPeriodDt
    offeredAmount
    offeredCreditsQuantity
    purchasedAmount
    purchasedCreditsQuantity
    startOfPeriodDt
    voidedAmount
    voidedCreditsQuantity
  }
`
const PREPAID_CREDITS_GRAPH_COLORS = {
  offeredAmount: '#ABF5DC',
  purchasedAmount: '#36B389',
  consumedAmount: '#FF8F73',
  voidedAmount: '#D9DEE7',
}

const AmountCell = ({
  value,
  className,
  currency,
}: {
  value: number
  className: string
  currency: CurrencyEnum
}) => {
  const formatted = toAmountCents(value, currency)

  return (
    <Typography variant="body" className={tw(className)}>
      {formatted}
    </Typography>
  )
}

const CreditsAmountCell = ({ value, currency }: { value: number; currency: CurrencyEnum }) => (
  <AmountCell
    className={tw({
      'text-green-600': value > 0,
      'text-grey-500': Number(value) === 0,
      'text-red-600': value < 0,
    })}
    value={value}
    currency={currency}
  />
)

const CreditsRowLabel = ({ label, color }: { label: string; color: string }) => (
  <div className="flex items-center gap-2">
    <div className="size-3 rounded-full" style={{ backgroundColor: color }} />

    <Typography className="font-medium text-grey-700">{label}</Typography>
  </div>
)

export const PrepaidCreditsOverviewSection = () => {
  const { translate } = useInternationalization()
  const premiumWarningDialog = usePremiumWarningDialog()

  const {
    selectedCurrency,
    defaultCurrency,
    data,
    hasError,
    isLoading,
    timeGranularity,
    getDefaultStaticDateFilter,
    getDefaultStaticTimeGranularityFilter,
    hasAccessToAnalyticsDashboardsFeature,
  } = usePrepaidCreditsAnalyticsOverview()

  return (
    <section className="flex flex-col gap-6">
      <div className="flex flex-col gap-4">
        <Filters.Provider
          filtersNamePrefix={PREPAID_CREDITS_OVERVIEW_FILTER_PREFIX}
          staticFilters={{
            currency: defaultCurrency,
            date: getDefaultStaticDateFilter(),
          }}
          staticQuickFilters={{
            timeGranularity: getDefaultStaticTimeGranularityFilter(),
          }}
          availableFilters={PrepaidCreditsOverviewAvailableFilters}
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
                  premiumWarningDialog.open()
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
              {translate('text_634687079be251fdb43833b7')}
            </Typography>

            <div className="flex items-center gap-1">
              <Filters.QuickFilters />
            </div>
          </div>

          <div className="flex w-full flex-col gap-3">
            <Filters.Component />
          </div>
        </Filters.Provider>
      </div>

      {hasError && (
        <GenericPlaceholder
          title={translate('text_636d023ce11a9d038819b579')}
          subtitle={translate('text_636d023ce11a9d038819b57b')}
          image={<ErrorImage width="136" height="104" />}
        />
      )}

      {!hasError && (
        <AnalyticsStateProvider>
          <StackedBarChart
            xAxisDataKey="startOfPeriodDt"
            xAxisTickAttributes={['startOfPeriodDt', 'endOfPeriodDt']}
            currency={selectedCurrency}
            data={data}
            loading={isLoading}
            timeGranularity={timeGranularity}
            bars={[
              {
                tooltipIndex: 1,
                barIndex: 0,
                dataKey: 'purchasedAmount',
                colorHex: PREPAID_CREDITS_GRAPH_COLORS.purchasedAmount,
                tooltipLabel: translate('text_17441926919314anbpq9h0t3'),
              },
              {
                tooltipIndex: 0,
                barIndex: 1,
                dataKey: 'offeredAmount',
                colorHex: PREPAID_CREDITS_GRAPH_COLORS.offeredAmount,
                tooltipLabel: translate('text_1744192691931pjtht59xxk0'),
              },
              {
                tooltipIndex: 2,
                barIndex: 3,
                dataKey: 'consumedAmount',
                colorHex: PREPAID_CREDITS_GRAPH_COLORS.consumedAmount,
                tooltipLabel: translate('text_17441926919313u9z1er36fh'),
              },
              {
                tooltipIndex: 3,
                barIndex: 4,
                dataKey: 'voidedAmount',
                colorHex: PREPAID_CREDITS_GRAPH_COLORS.voidedAmount,
                tooltipLabel: translate('text_1744192691931co5ozcxf9qw'),
              },
            ]}
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
                key: 'offeredAmount',
                type: 'data',
                label: (
                  <CreditsRowLabel
                    label={translate('text_1744192691931pjtht59xxk0')}
                    color={PREPAID_CREDITS_GRAPH_COLORS.offeredAmount}
                  />
                ),
                content: (item) => (
                  <CreditsAmountCell value={item.offeredAmount} currency={selectedCurrency} />
                ),
              },
              {
                key: 'purchasedAmount',
                type: 'data',
                label: (
                  <CreditsRowLabel
                    label={translate('text_17441926919314anbpq9h0t3')}
                    color={PREPAID_CREDITS_GRAPH_COLORS.purchasedAmount}
                  />
                ),
                content: (item) => (
                  <CreditsAmountCell value={item.purchasedAmount} currency={selectedCurrency} />
                ),
              },
              {
                key: 'consumedAmount',
                type: 'data',
                label: (
                  <CreditsRowLabel
                    label={translate('text_17441926919313u9z1er36fh')}
                    color={PREPAID_CREDITS_GRAPH_COLORS.consumedAmount}
                  />
                ),
                content: (item) => (
                  <CreditsAmountCell value={item.consumedAmount} currency={selectedCurrency} />
                ),
              },
              {
                key: 'voidedAmount',
                type: 'data',
                label: (
                  <CreditsRowLabel
                    label={translate('text_1744192691931co5ozcxf9qw')}
                    color={PREPAID_CREDITS_GRAPH_COLORS.voidedAmount}
                  />
                ),
                content: (item) => (
                  <CreditsAmountCell value={item.voidedAmount} currency={selectedCurrency} />
                ),
              },
            ]}
          />
        </AnalyticsStateProvider>
      )}
    </section>
  )
}
