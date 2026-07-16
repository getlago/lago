import { gql } from '@apollo/client'
import { useState } from 'react'
import { useParams, useSearchParams } from 'react-router-dom'

import { AnalyticsStateProvider } from '~/components/analytics/AnalyticsStateContext'
import { Filters } from '~/components/designSystem/Filters'
import { formatFiltersForCustomerAnalyticsQuery } from '~/components/designSystem/Filters/utils'
import Gross from '~/components/graphs/Gross'
import MonthSelectorDropdown, {
  AnalyticsPeriodScopeEnum,
  TPeriodScopeTranslationLookupValue,
} from '~/components/graphs/MonthSelectorDropdown'
import { PageSectionTitle } from '~/components/layouts/Section'
import { CUSTOMER_ANALYTICS_FILTER_PREFIX } from '~/core/constants/filters'
import { CurrencyEnum, useGetCustomerSubscriptionForUsageQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCustomerFilterDefaults } from '~/hooks/useCustomerFilterDefaults'

gql`
  query getCustomerSubscriptionForUsage($id: ID!) {
    customer(id: $id) {
      id
      externalId
      currency
    }
  }
`

export const CustomerUsage = () => {
  const { customerId = '' } = useParams()
  const { translate } = useInternationalization()
  const [searchParams] = useSearchParams()

  const [periodScope, setPeriodScope] = useState<TPeriodScopeTranslationLookupValue>(
    AnalyticsPeriodScopeEnum.Year,
  )
  const { data } = useGetCustomerSubscriptionForUsageQuery({
    variables: { id: customerId },
    skip: !customerId,
  })

  const filtersProps = useCustomerFilterDefaults({
    customerCurrency: data?.customer?.currency ?? undefined,
    filtersNamePrefix: CUSTOMER_ANALYTICS_FILTER_PREFIX,
    include: ['currency', 'entity'],
    withDefaults: true,
  })

  const { currency, billingEntityId } = formatFiltersForCustomerAnalyticsQuery(searchParams)

  return (
    <div>
      <PageSectionTitle
        title={translate('text_65564e8e4af2340050d431be')}
        subtitle={translate('text_173764736415670g9n7v9tth')}
        customAction={
          <MonthSelectorDropdown periodScope={periodScope} setPeriodScope={setPeriodScope} />
        }
      />

      {filtersProps && (
        <Filters.Provider {...filtersProps}>
          <div className="mb-4 flex items-center gap-2">
            <Filters.Component />
          </div>
        </Filters.Provider>
      )}

      <AnalyticsStateProvider>
        <Gross
          className="analytics-graph py-0"
          currency={currency ?? CurrencyEnum.Usd}
          period={periodScope}
          externalCustomerId={data?.customer?.externalId}
          billingEntityId={billingEntityId}
        />
      </AnalyticsStateProvider>
    </div>
  )
}
