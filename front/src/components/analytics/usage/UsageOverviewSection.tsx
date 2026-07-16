import { Icon } from 'lago-design-system'

import { AnalyticsStateProvider } from '~/components/analytics/AnalyticsStateContext'
import { useUsageAnalyticsOverview } from '~/components/analytics/usage/useUsageAnalyticsOverview'
import { Button } from '~/components/designSystem/Button'
import {
  AvailableQuickFilters,
  Filters,
  UsageOverviewAvailableFilters,
} from '~/components/designSystem/Filters'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import AreaChart from '~/components/designSystem/graphs/AreaChart'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { ANALYTICS_USAGE_OVERVIEW_FILTER_PREFIX } from '~/core/constants/filters'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import ErrorImage from '~/public/images/maneki/error.svg'

const UsageOverviewSection = () => {
  const { translate } = useInternationalization()
  const premiumWarningDialog = usePremiumWarningDialog()

  const {
    selectedCurrency,
    defaultCurrency,
    hasError,
    isLoading,
    totalAmountCents,
    getDefaultStaticDateFilter,
    getDefaultStaticTimeGranularityFilter,
    hasAccessToAnalyticsDashboardsFeature,
    formattedDataForAreaChart,
  } = useUsageAnalyticsOverview()

  return (
    <section className="flex flex-col gap-6">
      <Filters.Provider
        filtersNamePrefix={ANALYTICS_USAGE_OVERVIEW_FILTER_PREFIX}
        staticFilters={{
          currency: defaultCurrency,
          date: getDefaultStaticDateFilter(),
        }}
        staticQuickFilters={{
          timeGranularity: getDefaultStaticTimeGranularityFilter(),
        }}
        availableFilters={UsageOverviewAvailableFilters}
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
        <div className="flex flex-col gap-12">
          <div className="flex justify-between">
            <Typography className="flex items-center gap-2" variant="headline" color="grey700">
              {translate('text_17465414264635ktqocy7leo')}

              <Tooltip
                placement="top-start"
                title={translate('text_1747817451282js22pfg16gg')}
                className="flex"
              >
                <Icon name="info-circle" className="text-grey-600" />
              </Tooltip>
            </Typography>

            <div className="flex items-center gap-1">
              <Filters.QuickFilters />
            </div>
          </div>

          <div className="flex flex-col gap-4">
            <div className="flex items-center justify-between">
              <Typography variant="subhead1" color="grey700">
                {translate('text_1746541426463b1mm6097u0e')}
              </Typography>
            </div>

            <div className="flex w-full flex-col gap-3">
              <Filters.Component />
            </div>
          </div>
        </div>
      </Filters.Provider>

      <div className="flex flex-col gap-1">
        <Typography variant="headline" color="grey700">
          {intlFormatNumber(deserializeAmount(totalAmountCents || 0, selectedCurrency), {
            currencyDisplay: 'symbol',
            currency: selectedCurrency,
          })}
        </Typography>
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
        </AnalyticsStateProvider>
      )}
    </section>
  )
}

export default UsageOverviewSection
