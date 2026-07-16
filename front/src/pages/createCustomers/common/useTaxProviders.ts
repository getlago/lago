import { gql } from '@apollo/client'

import {
  GetTaxIntegrationsForExternalAppsAccordionQuery,
  IntegrationTypeEnum,
  useGetTaxIntegrationsForExternalAppsAccordionQuery,
} from '~/generated/graphql'

gql`
  query getTaxIntegrationsForExternalAppsAccordion($limit: Int, $page: Int) {
    integrations(limit: $limit, page: $page) {
      collection {
        ... on AnrokIntegration {
          __typename
          id
          code
          name
        }
        ... on AvalaraIntegration {
          __typename
          id
          code
          name
        }
      }
    }
  }
`

export const useTaxProviders = (): {
  taxProviders: GetTaxIntegrationsForExternalAppsAccordionQuery | undefined
  isLoadingTaxProviders: boolean
  getTaxProviderFromCode: (code: string | undefined) => IntegrationTypeEnum | undefined
} => {
  const { data: taxProviders, loading: isLoadingTaxProviders } =
    useGetTaxIntegrationsForExternalAppsAccordionQuery({
      variables: { limit: 1000 },
    })

  const getTaxProviderFromCode = (code: string | undefined): IntegrationTypeEnum | undefined => {
    if (!code) return undefined

    const provider = taxProviders?.integrations?.collection.find(
      (p) => 'code' in p && p.code === code,
    )

    if (!provider?.__typename) return undefined

    return provider.__typename.toLocaleLowerCase().replace('integration', '') as IntegrationTypeEnum
  }

  return {
    taxProviders,
    isLoadingTaxProviders,
    getTaxProviderFromCode,
  }
}
