import { gql } from '@apollo/client'
import { useMemo } from 'react'
import { useSearchParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import {
  Filters,
  formatFiltersForRevenueStreamsCustomersQuery,
  RevenueStreamsCustomersAvailableFilters,
} from '~/components/designSystem/Filters'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { REVENUE_STREAMS_BREAKDOWN_CUSTOMER_FILTER_PREFIX } from '~/core/constants/filters'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import {
  CurrencyEnum,
  PremiumIntegrationTypeEnum,
  useGetRevenueStreamsCustomerBreakdownQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

gql`
  query getRevenueStreamsCustomerBreakdown($currency: CurrencyEnum, $limit: Int, $page: Int) {
    dataApiRevenueStreamsCustomers(currency: $currency, limit: $limit, page: $page) {
      collection {
        amountCurrency
        customerDeletedAt
        customerName
        externalCustomerId
        grossRevenueAmountCents
        grossRevenueShare
      }
      metadata {
        currentPage
        totalPages
      }
    }
  }
`

export const RevenueStreamsCustomerBreakdownSection = () => {
  const [searchParams] = useSearchParams()
  const { organization, hasOrganizationPremiumAddon } = useOrganizationInfos()
  const { translate } = useInternationalization()
  const premiumWarningDialog = usePremiumWarningDialog()

  const hasAccessToAnalyticsDashboardsFeature = hasOrganizationPremiumAddon(
    PremiumIntegrationTypeEnum.AnalyticsDashboards,
  )
  const defaultCurrency = organization?.defaultCurrency || CurrencyEnum.Usd

  const filtersForRevenueStreamsQuery = useMemo(() => {
    if (!hasAccessToAnalyticsDashboardsFeature) {
      return {
        currency: defaultCurrency,
      }
    }

    return formatFiltersForRevenueStreamsCustomersQuery(searchParams)
  }, [hasAccessToAnalyticsDashboardsFeature, searchParams, defaultCurrency])

  const {
    data: revenueStreamsCustomerBreakdownData,
    loading: revenueStreamsCustomerBreakdownLoading,
    error: revenueStreamsCustomerBreakdownError,
    fetchMore,
    variables,
  } = useGetRevenueStreamsCustomerBreakdownQuery({
    notifyOnNetworkStatusChange: true,
    variables: {
      ...filtersForRevenueStreamsQuery,
      limit: 20,
    },
  })

  return (
    <>
      <div className="flex flex-col">
        <Filters.Provider
          filtersNamePrefix={REVENUE_STREAMS_BREAKDOWN_CUSTOMER_FILTER_PREFIX}
          staticFilters={{
            currency: defaultCurrency,
          }}
          availableFilters={RevenueStreamsCustomersAvailableFilters}
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
          <div className="flex w-full flex-col gap-3 py-3 shadow-b">
            <Filters.Component />
          </div>
        </Filters.Provider>
      </div>

      <InfiniteScroll
        onBottom={() => {
          const { currentPage = 0, totalPages = 0 } =
            revenueStreamsCustomerBreakdownData?.dataApiRevenueStreamsCustomers.metadata || {}

          currentPage < totalPages &&
            !revenueStreamsCustomerBreakdownLoading &&
            fetchMore({
              variables: {
                ...variables,
                page: currentPage + 1,
              },
            })
        }}
      >
        <Table
          name="revenue-streams-customer-breakdown"
          containerSize={{ default: 0 }}
          rowSize={72}
          isLoading={revenueStreamsCustomerBreakdownLoading}
          hasError={!!revenueStreamsCustomerBreakdownError}
          data={
            revenueStreamsCustomerBreakdownData?.dataApiRevenueStreamsCustomers.collection.map(
              (c) => ({
                id: c.externalCustomerId,
                ...c,
              }),
            ) || []
          }
          placeholder={{
            emptyState: {
              title: translate('text_17422274967581grox8em361'),
              subtitle: translate('text_1742227496758jg629m9fga6'),
            },
          }}
          columns={[
            {
              key: 'customerName',
              title: translate('text_63d3a658c6d84a5843032145'),
              maxSpace: true,
              minWidth: 200,
              content({ customerName, externalCustomerId, customerDeletedAt }) {
                return (
                  <>
                    <div className="flex items-baseline gap-1">
                      <Typography color="grey700" variant="bodyHl">
                        {customerName || '-'}
                      </Typography>
                      {!!customerDeletedAt && (
                        <Typography variant="caption" color="grey600">
                          ({translate('text_1743158702704o1juwxmr4ab')})
                        </Typography>
                      )}
                    </div>
                    <Typography variant="caption" color="grey600">
                      {externalCustomerId}
                    </Typography>
                  </>
                )
              },
            },
            {
              key: 'grossRevenueShare',
              title: translate('text_17422232171950c2u9u3vuq7'),
              textAlign: 'right',
              minWidth: 134,
              content({ grossRevenueShare, grossRevenueAmountCents, amountCurrency }) {
                return (
                  <div className="flex items-center gap-2">
                    <Typography variant="body" color="grey700">
                      {intlFormatNumber(
                        deserializeAmount(grossRevenueAmountCents || 0, amountCurrency),
                        {
                          style: 'currency',
                          currency: amountCurrency,
                        },
                      )}
                    </Typography>
                    <Typography className="w-16 text-right" variant="body" color="grey600">
                      {intlFormatNumber(grossRevenueShare || 0, { style: 'percent' })}
                    </Typography>
                  </div>
                )
              },
            },
          ]}
        />
      </InfiniteScroll>
    </>
  )
}
