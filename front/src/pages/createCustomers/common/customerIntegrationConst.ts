import { IntegrationTypeEnum } from '~/generated/graphql'

export const integrationTypeToTypename: Partial<Record<IntegrationTypeEnum, string>> = {
  // Account integrations
  [IntegrationTypeEnum.Netsuite]: 'NetsuiteIntegration',
  [IntegrationTypeEnum.Xero]: 'XeroIntegration',
  // Tax integrations
  [IntegrationTypeEnum.Anrok]: 'AnrokIntegration',
  [IntegrationTypeEnum.Avalara]: 'AvalaraIntegration',
  // CRM integrations
  [IntegrationTypeEnum.Hubspot]: 'HubspotIntegration',
  [IntegrationTypeEnum.Salesforce]: 'SalesforceIntegration',
}
