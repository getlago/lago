import { FetchResult } from '@apollo/client'

import { LagoGQLError } from '~/core/apolloClient/errorUtils'

export const hasNonEuEligibilityError = (results: FetchResult[]): boolean => {
  return results.some((res) =>
    res.errors?.some((err) => {
      const details = (err.extensions as LagoGQLError['extensions'])?.details

      return details?.['euTaxManagement']?.includes('billing_entity_must_be_in_eu')
    }),
  )
}
