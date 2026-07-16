import {
  AnrokIntegration,
  AvalaraIntegration,
  GetAccountingIntegrationsForExternalAppsAccordionQuery,
  GetCrmIntegrationsForExternalAppsAccordionQuery,
  GetTaxIntegrationsForExternalAppsAccordionQuery,
  HubspotIntegration,
  IntegrationCustomerInput,
  IntegrationTypeEnum,
  NetsuiteIntegration,
  SalesforceIntegration,
  XeroIntegration,
} from '~/generated/graphql'
import { getAllIntegrationForAnIntegrationType } from '~/pages/createCustomers/common/getAllIntegrationForAnIntegrationType'

import { CreateCustomerDefaultValues } from '../formInitialization/validationSchema'

export const getIntegrationCustomers = ({
  taxProviderCode,
  accountingProviderCode,
  crmProviderCode,
  taxProviders,
  accountingProviders,
  crmProviders,
  accountingCustomer,
  crmCustomer,
  taxCustomer,
}: {
  taxProviderCode?: string
  accountingProviderCode?: string
  crmProviderCode?: string
  taxProviders?: GetTaxIntegrationsForExternalAppsAccordionQuery
  accountingProviders?: GetAccountingIntegrationsForExternalAppsAccordionQuery
  crmProviders?: GetCrmIntegrationsForExternalAppsAccordionQuery
  accountingCustomer?: CreateCustomerDefaultValues['accountingCustomer']
  crmCustomer?: CreateCustomerDefaultValues['crmCustomer']
  taxCustomer?: CreateCustomerDefaultValues['taxCustomer']
}): Array<IntegrationCustomerInput> => {
  if (!taxProviderCode && !accountingProviderCode && !crmProviderCode) {
    return []
  }

  // We need to do it this way because of strange typing coming from back
  const taxIntegrations = [
    ...(getAllIntegrationForAnIntegrationType<AnrokIntegration>({
      integrationType: IntegrationTypeEnum.Anrok,
      allIntegrationsData: taxProviders,
    }) || []),
    ...(getAllIntegrationForAnIntegrationType<AvalaraIntegration>({
      integrationType: IntegrationTypeEnum.Avalara,
      allIntegrationsData: taxProviders,
    }) || []),
  ]

  const accountingIntegrations = [
    ...(getAllIntegrationForAnIntegrationType<NetsuiteIntegration>({
      integrationType: IntegrationTypeEnum.Netsuite,
      allIntegrationsData: accountingProviders,
    }) || []),
    ...(getAllIntegrationForAnIntegrationType<XeroIntegration>({
      integrationType: IntegrationTypeEnum.Xero,
      allIntegrationsData: accountingProviders,
    }) || []),
  ]

  const crmIntegrations = [
    ...(getAllIntegrationForAnIntegrationType<HubspotIntegration>({
      integrationType: IntegrationTypeEnum.Hubspot,
      allIntegrationsData: crmProviders,
    }) || []),
    ...(getAllIntegrationForAnIntegrationType<SalesforceIntegration>({
      integrationType: IntegrationTypeEnum.Salesforce,
      allIntegrationsData: crmProviders,
    }) || []),
  ]

  const taxProvider = taxIntegrations.find((integration) => integration.code === taxProviderCode)
  const accountingProvider = accountingIntegrations.find(
    (integration) => integration.code === accountingProviderCode,
  )
  const crmProvider = crmIntegrations.find((integration) => integration.code === crmProviderCode)

  if (!taxProvider && !accountingProvider && !crmProvider) {
    return []
  }

  const subsidiaryObject = accountingCustomer?.subsidiaryId
    ? { subsidiaryId: accountingCustomer?.subsidiaryId }
    : {}

  const targetObject = crmCustomer?.targetedObject
    ? { targetedObject: crmCustomer?.targetedObject }
    : {}

  return [
    ...(taxProvider
      ? [
          {
            id: taxCustomer?.id,
            integrationCode: taxProvider.code,
            integrationType: taxProvider.__typename
              ?.toLowerCase()
              .replace('integration', '') as IntegrationTypeEnum,
            syncWithProvider: taxCustomer?.syncWithProvider,
            externalCustomerId: taxCustomer?.taxCustomerId,
          },
        ]
      : []),
    ...(accountingProvider
      ? [
          {
            id: accountingCustomer?.id,
            integrationCode: accountingProvider.code,
            integrationType: accountingProvider.__typename
              ?.toLowerCase()
              .replace('integration', '') as IntegrationTypeEnum,
            syncWithProvider: accountingCustomer?.syncWithProvider,
            externalCustomerId: accountingCustomer?.accountingCustomerId,
            ...subsidiaryObject,
          },
        ]
      : []),
    ...(crmProvider
      ? [
          {
            id: crmCustomer?.id,
            integrationCode: crmProvider.code,
            integrationType: crmProvider.__typename
              ?.toLowerCase()
              .replace('integration', '') as IntegrationTypeEnum,
            syncWithProvider: crmCustomer?.syncWithProvider,
            externalCustomerId: crmCustomer?.crmCustomerId,
            ...targetObject,
          },
        ]
      : []),
  ]
}
