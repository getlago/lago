import { gql } from '@apollo/client'

import {
  GetAccountingIntegrationsForExternalAppsAccordionQuery,
  IntegrationTypeEnum,
  useGetAccountingIntegrationsForExternalAppsAccordionQuery,
} from '~/generated/graphql'

gql`
  query getAccountingIntegrationsForExternalAppsAccordion($limit: Int, $page: Int) {
    integrations(limit: $limit, page: $page) {
      collection {
        ... on NetsuiteIntegration {
          __typename
          id
          code
          name
        }
        ... on XeroIntegration {
          __typename
          id
          code
          name
        }
      }
    }
  }
`

export const useAccountingProviders = (): {
  accountingProviders: GetAccountingIntegrationsForExternalAppsAccordionQuery | undefined
  isLoadingAccountProviders: boolean
  getAccountingProviderFromCode: (code: string | undefined) => IntegrationTypeEnum | undefined
} => {
  const { data: accountingProviders, loading: isLoadingAccountProviders } =
    useGetAccountingIntegrationsForExternalAppsAccordionQuery({
      variables: { limit: 1000 },
    })

  const getAccountingProviderFromCode = (
    code: string | undefined,
  ): IntegrationTypeEnum | undefined => {
    if (!code) return undefined

    const provider = accountingProviders?.integrations?.collection.find(
      (p) => 'code' in p && p.code === code,
    )

    if (!provider?.__typename) return undefined

    return provider.__typename.toLocaleLowerCase().replace('integration', '') as IntegrationTypeEnum
  }

  return {
    accountingProviders,
    isLoadingAccountProviders,
    getAccountingProviderFromCode,
  }
}
