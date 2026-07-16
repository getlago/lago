import { gql } from '@apollo/client'

import {
  GetCrmIntegrationsForExternalAppsAccordionQuery,
  IntegrationTypeEnum,
  useGetCrmIntegrationsForExternalAppsAccordionQuery,
} from '~/generated/graphql'

gql`
  query getCrmIntegrationsForExternalAppsAccordion($limit: Int, $page: Int) {
    integrations(limit: $limit, page: $page) {
      collection {
        ... on HubspotIntegration {
          __typename
          id
          code
          name
          defaultTargetedObject
        }
        ... on SalesforceIntegration {
          __typename
          id
          code
          name
        }
      }
    }
  }
`

export const useCrmProviders = (): {
  crmProviders: GetCrmIntegrationsForExternalAppsAccordionQuery | undefined
  isLoadingCrmProviders: boolean
  getCrmProviderFromCode: (code: string | undefined) => IntegrationTypeEnum | undefined
} => {
  const { data: crmProviders, loading: isLoadingCrmProviders } =
    useGetCrmIntegrationsForExternalAppsAccordionQuery({
      variables: { limit: 1000 },
    })

  const getCrmProviderFromCode = (code: string | undefined): IntegrationTypeEnum | undefined => {
    if (!code) return undefined

    const provider = crmProviders?.integrations?.collection.find(
      (p) => 'code' in p && p.code === code,
    )

    if (!provider?.__typename) return undefined

    return provider.__typename.toLocaleLowerCase().replace('integration', '') as IntegrationTypeEnum
  }

  return {
    crmProviders,
    isLoadingCrmProviders,
    getCrmProviderFromCode,
  }
}
