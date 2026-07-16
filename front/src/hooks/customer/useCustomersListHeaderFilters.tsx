import { ReactNode } from 'react'

import {
  AvailableFiltersEnum,
  AvailableQuickFilters,
  CustomerAvailableFilters,
  Filters,
} from '~/components/designSystem/Filters'
import { SearchInput } from '~/components/SearchInput'
import { CUSTOMER_LIST_FILTER_PREFIX } from '~/core/constants/filters'
import { PremiumIntegrationTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { UseDebouncedSearch } from '~/hooks/useDebouncedSearch'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

interface UseCustomersListFiltersSectionParams {
  debouncedSearch: ReturnType<UseDebouncedSearch>['debouncedSearch']
}

export function useCustomersListHeaderFilters({
  debouncedSearch,
}: UseCustomersListFiltersSectionParams): ReactNode {
  const { translate } = useInternationalization()
  const { hasOrganizationPremiumAddon } = useOrganizationInfos()

  const hasAccessToRevenueShare = hasOrganizationPremiumAddon(
    PremiumIntegrationTypeEnum.RevenueShare,
  )

  const availableFilters = hasAccessToRevenueShare
    ? CustomerAvailableFilters
    : CustomerAvailableFilters.filter(
        (filter) => filter !== AvailableFiltersEnum.customerAccountType,
      )

  return (
    <Filters.Provider
      filtersNamePrefix={CUSTOMER_LIST_FILTER_PREFIX}
      quickFiltersType={AvailableQuickFilters.customerAccountType}
      availableFilters={availableFilters}
    >
      <div className="flex flex-col gap-4">
        <Filters.QuickFilters />
        <div className="flex flex-col gap-3 md:flex-row md:items-center">
          <SearchInput
            onChange={debouncedSearch}
            placeholder={translate('text_63befc65efcd9374da45b801')}
            data-test="search-customers"
          />
          <Filters.Component />
        </div>
      </div>
    </Filters.Provider>
  )
}
