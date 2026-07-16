import { gql } from '@apollo/client'
import { useMemo } from 'react'

import {
  GetCustomPricingUnitsQuery,
  LagoApiError,
  useGetCustomPricingUnitsQuery,
} from '~/generated/graphql'
import { usePermissions } from '~/hooks/usePermissions'

gql`
  query getCustomPricingUnits($limit: Int, $page: Int) {
    pricingUnits(limit: $limit, page: $page) {
      collection {
        id
        name
        code
        shortName
      }
      metadata {
        currentPage
        totalPages
      }
    }
  }
`

interface UseCustomPricingUnitsReturn {
  hasAnyPricingUnitConfigured: boolean
  pricingUnits: GetCustomPricingUnitsQuery['pricingUnits']['collection']
}

export const useCustomPricingUnits = (): UseCustomPricingUnitsReturn => {
  const { hasPermissions } = usePermissions()
  const canViewPricingUnits = hasPermissions(['pricingUnitsView'])

  const { data } = useGetCustomPricingUnitsQuery({
    context: { silentError: LagoApiError.NotFound },
    variables: { limit: 100, page: 1 },
    skip: !canViewPricingUnits,
  })

  const pricingUnits = useMemo(() => {
    return data?.pricingUnits?.collection || []
  }, [data?.pricingUnits?.collection])

  return useMemo(
    () => ({
      hasAnyPricingUnitConfigured: pricingUnits.length > 0,
      pricingUnits,
    }),
    [pricingUnits],
  )
}
