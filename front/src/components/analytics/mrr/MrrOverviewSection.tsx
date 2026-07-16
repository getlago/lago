import { gql } from '@apollo/client'
import { Icon } from 'lago-design-system'

import { AnalyticsStateProvider } from '~/components/analytics/AnalyticsStateContext'
import { useMrrAnalyticsOverview } from '~/components/analytics/mrr/useMrrAnalyticsOverview'
import { Button } from '~/components/designSystem/Button'
import {
  AvailableQuickFilters,
  Filters,
  MrrOverviewAvailableFilters,
} from '~/components/designSystem/Filters'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import AreaChart from '~/components/designSystem/graphs/AreaChart'
import { getItemDateFormatedByTimeGranularity } from '~/components/designSystem/graphs/utils'
import { HorizontalDataTable } from '~/components/designSystem/Table/HorizontalDataTable'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { MRR_BREAKDOWN_OVERVIEW_FILTER_PREFIX } from '~/core/constants/filters'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum, TimeGranularityEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import ErrorImage from '~/public/images/maneki/error.svg'
import { tw } from '~/styles/utils'

gql`
  fragment MrrDataForOverviewSection on DataApiMrr {
    endOfPeriodDt
    endingMrr
    mrrChange
    mrrChurn
    mrrContraction
    mrrExpansion
    mrrNew
    startOfPeriodDt
    startingMrr
  }
`

const AmountCell = ({
  value,
  className,
  currency,
  showMinusSign = false,
}: {
  value: number
  className: string
  currency: CurrencyEnum
  showMinusSign?: boolean
}) => {
  return (
    <Typography variant="body" className={tw(className)}>
      {showMinusSign && '-'}
      {intlFormatNumber(deserializeAmount(value, currency), {
        currencyDisplay: 'symbol',
        currency,
      })}
    </Typography>
  )
}

export const MrrOverviewSection = () => {
  const { translate } = useInternationalization()
  const premiumWarningDialog = usePremiumWarningDialog()
  const {
    selectedCurrency,
    defaultCurrency,
    data,
    hasError,
    isLoading,
    lastMrrAmountCents,
    mrrAmountCentsProgressionOnPeriod,
    timeGranularity,
    getDefaultStaticDateFilter,
    getDefaultStaticTimeGranularityFilter,
    hasAccessToAnalyticsDashboardsFeature,
    formattedDataForAreaChart,
  } = useMrrAnalyticsOverview()

  return (
    <section className="flex flex-col gap-6">
      <div className="flex flex-col gap-4">
        <Filters.Provider
          filtersNamePrefix={MRR_BREAKDOWN_OVERVIEW_FILTER_PREFIX}
          staticFilters={{
            currency: defaultCurrency,
            date: getDefaultStaticDateFilter(),
          }}
          staticQuickFilters={{
            timeGranularity: getDefaultStaticTimeGranularityFilter(),
          }}
          availableFilters={MrrOverviewAvailableFilters}
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

      <div className="flex flex-col gap-1">
        <Typography variant="headline" color="grey700">
          {intlFormatNumber(deserializeAmount(lastMrrAmountCents || 0, selectedCurrency), {
            currencyDisplay: 'symbol',
            currency: selectedCurrency,
          })}
        </Typography>
        <div className="flex items-center gap-2">
          <Icon
            name={
              Number(mrrAmountCentsProgressionOnPeriod) > 0
                ? 'arrow-up-circle-filled'
                : 'arrow-down-circle-filled'
            }
            color={Number(mrrAmountCentsProgressionOnPeriod) > 0 ? 'success' : 'error'}
          />
          <div className="flex items-center gap-1">
            <Typography
              variant="caption"
              color={Number(mrrAmountCentsProgressionOnPeriod) > 0 ? 'success600' : 'danger600'}
            >
              {intlFormatNumber(Number(mrrAmountCentsProgressionOnPeriod), {
                style: 'percent',
              })}
            </Typography>
            <Typography variant="caption" color="grey700">
              {translate('text_174048163137011wdtjb1xfg')}
            </Typography>
          </div>
        </div>
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
          <AreaChart
            height={232}
            tickFontSize={14}
            blur={false}
            currency={selectedCurrency}
            data={formattedDataForAreaChart}
            loading={isLoading}
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
                key: 'mrrNew',
                type: 'data',
                label: translate('text_1742831422968chcjxyc2qjo'),
                content: (item) => {
                  const newMrrAmountCents = Number(item.mrrNew) || 0

                  return (
                    <AmountCell
                      className={tw({
                        'text-green-600': newMrrAmountCents > 0,
                        'text-grey-500': newMrrAmountCents === 0,
                      })}
                      value={newMrrAmountCents}
                      currency={selectedCurrency}
                    />
                  )
                },
              },
              {
                key: 'mrrExpansion',
                type: 'data',
                label: translate('text_17429967574516lh8r3sznyt'),
                content: (item) => {
                  const expansionMrrAmountCents = Number(item.mrrExpansion) || 0

                  return (
                    <AmountCell
                      className={tw({
                        'text-green-600': expansionMrrAmountCents > 0,
                        'text-grey-500': expansionMrrAmountCents === 0,
                      })}
                      value={expansionMrrAmountCents}
                      currency={selectedCurrency}
                    />
                  )
                },
              },
              {
                key: 'mrrContraction',
                type: 'data',
                label: translate('text_1742996757451c2a49pod8hm'),
                content: (item) => {
                  const contractionMrrAmountCents = Number(item.mrrContraction) || 0

                  return (
                    <AmountCell
                      className={tw({
                        'text-red-600': contractionMrrAmountCents < 0,
                        'text-grey-500': contractionMrrAmountCents === 0,
                      })}
                      value={contractionMrrAmountCents}
                      currency={selectedCurrency}
                    />
                  )
                },
              },
              {
                key: 'mrrChurn',
                type: 'data',
                label: translate('text_1742996757451llxiqw85bvu'),
                content: (item) => {
                  const churnMrrAmountCents = Number(item.mrrChurn) || 0

                  return (
                    <AmountCell
                      className={tw({
                        'text-red-600': churnMrrAmountCents < 0,
                        'text-grey-500': churnMrrAmountCents === 0,
                      })}
                      value={churnMrrAmountCents}
                      currency={selectedCurrency}
                    />
                  )
                },
              },
              {
                key: 'startOfPeriodDt',
                type: 'header',
                label: translate('text_174299767573783t24sdrsp1'),
                content: (item) => {
                  return (
                    <Typography variant="captionHl">
                      {getItemDateFormatedByTimeGranularity({ item, timeGranularity })}
                    </Typography>
                  )
                },
              },
              {
                key: 'startingMrr',
                type: 'data',
                label: translate('text_1742996757451ng6z8o2xif2'),
                content: (item) => {
                  const startingMrrAmountCents = Number(item.startingMrr) || 0

                  return (
                    <AmountCell
                      className={tw({
                        'text-green-600': startingMrrAmountCents > 0,
                        'text-grey-500': startingMrrAmountCents === 0,
                      })}
                      value={startingMrrAmountCents}
                      currency={selectedCurrency}
                    />
                  )
                },
              },
              {
                key: 'mrrChange',
                type: 'data',
                label: translate('text_1742996757451700705sjtf8'),
                content: (item) => {
                  const mrrChangeAmountCents = Number(item.mrrChange) || 0

                  return (
                    <AmountCell
                      className={tw({
                        'text-green-600': mrrChangeAmountCents > 0,
                        'text-red-600': mrrChangeAmountCents < 0,
                        'text-grey-500': mrrChangeAmountCents === 0,
                      })}
                      value={mrrChangeAmountCents}
                      currency={selectedCurrency}
                    />
                  )
                },
              },
              {
                key: 'endingMrr',
                type: 'data',
                label: translate('text_17429967574517l2yykxqmau'),
                content: (item) => {
                  const endingMrrAmountCents = Number(item.endingMrr) || 0

                  return (
                    <AmountCell
                      className={tw({
                        'text-green-600': endingMrrAmountCents > 0,
                        'text-grey-500': endingMrrAmountCents === 0,
                      })}
                      value={endingMrrAmountCents}
                      currency={selectedCurrency}
                    />
                  )
                },
              },
            ]}
          />
        </AnalyticsStateProvider>
      )}
    </section>
  )
}
