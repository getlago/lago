import { gql } from '@apollo/client'
import { useMemo } from 'react'
import { useSearchParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import {
  Filters,
  formatFiltersForMrrPlansQuery,
  MrrBreakdownPlansAvailableFilters,
} from '~/components/designSystem/Filters'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { MRR_BREAKDOWN_PLANS_FILTER_PREFIX } from '~/core/constants/filters'
import { getIntervalTranslationKey } from '~/core/constants/form'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import {
  CurrencyEnum,
  PremiumIntegrationTypeEnum,
  useGetMrrPlanBreakdownQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

gql`
  query getMrrPlanBreakdown($currency: CurrencyEnum, $limit: Int, $page: Int) {
    dataApiMrrsPlans(currency: $currency, limit: $limit, page: $page) {
      collection {
        activeCustomersCount
        activeCustomersShare
        amountCurrency
        mrr
        mrrShare
        planCode
        planDeletedAt
        planId
        planInterval
        planName
      }
      metadata {
        currentPage
        totalPages
      }
    }
  }
`

export const MrrBreakdownSection = () => {
  const [searchParams] = useSearchParams()
  const { translate } = useInternationalization()
  const premiumWarningDialog = usePremiumWarningDialog()
  const { organization, hasOrganizationPremiumAddon } = useOrganizationInfos()

  const hasAccessToAnalyticsDashboardsFeature = hasOrganizationPremiumAddon(
    PremiumIntegrationTypeEnum.AnalyticsDashboards,
  )
  const defaultCurrency = organization?.defaultCurrency || CurrencyEnum.Usd

  const filtersForMrrQuery = useMemo(() => {
    if (!hasAccessToAnalyticsDashboardsFeature) {
      return {
        currency: defaultCurrency,
      }
    }

    return formatFiltersForMrrPlansQuery(searchParams)
  }, [hasAccessToAnalyticsDashboardsFeature, searchParams, defaultCurrency])

  const {
    data: mrrPlanBreakdownData,
    loading: mrrPlanBreakdownLoading,
    error: mrrPlanBreakdownError,
    fetchMore,
    variables,
  } = useGetMrrPlanBreakdownQuery({
    notifyOnNetworkStatusChange: true,
    variables: {
      ...filtersForMrrQuery,
      limit: 20,
    },
  })

  return (
    <section className="flex flex-col gap-6">
      <div className="flex flex-col gap-4">
        <div className="flex flex-col gap-2">
          <Typography variant="subhead1" color="grey700">
            {translate('text_17424672790819r1ua5ujpt3')}
          </Typography>
          <Typography variant="caption" color="grey600">
            {translate('text_1742467700262idvii8tpg2w')}
          </Typography>
        </div>

        <Filters.Provider
          filtersNamePrefix={MRR_BREAKDOWN_PLANS_FILTER_PREFIX}
          staticFilters={{
            currency: defaultCurrency,
          }}
          availableFilters={MrrBreakdownPlansAvailableFilters}
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
          <div className="flex w-full flex-col gap-3">
            <Filters.Component />
          </div>
        </Filters.Provider>
      </div>

      <InfiniteScroll
        onBottom={() => {
          const { currentPage = 0, totalPages = 0 } =
            mrrPlanBreakdownData?.dataApiMrrsPlans.metadata || {}

          currentPage < totalPages &&
            !mrrPlanBreakdownLoading &&
            fetchMore({
              variables: {
                ...variables,
                page: currentPage + 1,
              },
            })
        }}
      >
        <Table
          name="mrr-plan-breakdown"
          containerSize={{ default: 0 }}
          rowSize={72}
          isLoading={mrrPlanBreakdownLoading}
          hasError={!!mrrPlanBreakdownError}
          data={
            mrrPlanBreakdownData?.dataApiMrrsPlans.collection.map((p) => ({
              id: p.planId,
              ...p,
            })) || []
          }
          placeholder={{
            emptyState: {
              title: translate('text_17422274791228swi7c4ydc7'),
              subtitle: translate('text_17422274791226kjpamwz3pe'),
            },
          }}
          columns={[
            {
              key: 'planName',
              title: translate('text_63d3a658c6d84a5843032145'),
              maxSpace: true,
              minWidth: 200,
              content({ planName, planCode, planDeletedAt }) {
                return (
                  <>
                    <div className="flex items-baseline gap-1">
                      <Typography color="grey700" variant="bodyHl">
                        {planName || '-'}
                      </Typography>
                      {!!planDeletedAt && (
                        <Typography variant="caption" color="grey600">
                          ({translate('text_1743158702704o1juwxmr4ab')})
                        </Typography>
                      )}
                    </div>
                    <Typography variant="caption" color="grey600">
                      {planCode}
                    </Typography>
                  </>
                )
              },
            },
            {
              key: 'planInterval',
              title: translate('text_65201b8216455901fe273dc1'),
              minWidth: 120,
              content({ planInterval }) {
                return (
                  <Typography variant="body">
                    {translate(getIntervalTranslationKey[planInterval])}
                  </Typography>
                )
              },
            },
            {
              key: 'activeCustomersShare',
              textAlign: 'right',
              title: translate('text_1742480465327lfl86dyjywx'),
              minWidth: 147,
              content({ activeCustomersShare, activeCustomersCount }) {
                return (
                  <div className="flex items-center gap-2">
                    <Typography variant="body" color="grey700">
                      {activeCustomersCount}
                    </Typography>
                    <Typography className="w-16" variant="body" color="grey600">
                      {intlFormatNumber(activeCustomersShare, { style: 'percent' })}
                    </Typography>
                  </div>
                )
              },
            },
            {
              key: 'mrrShare',
              title: translate('text_6553885df387fd0097fd738c'),
              textAlign: 'right',
              minWidth: 148,
              content({ mrrShare, mrr, amountCurrency }) {
                return (
                  <div className="flex items-center gap-2">
                    <Typography variant="body" color="grey700">
                      {intlFormatNumber(deserializeAmount(mrr || 0, amountCurrency), {
                        style: 'currency',
                        currency: amountCurrency,
                      })}
                    </Typography>
                    <Typography className="w-16 text-right" variant="body" color="grey600">
                      {intlFormatNumber(mrrShare || 0, { style: 'percent' })}
                    </Typography>
                  </div>
                )
              },
            },
          ]}
        />
      </InfiniteScroll>
    </section>
  )
}
