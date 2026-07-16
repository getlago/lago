import {
  AnrokIntegration,
  AvalaraIntegration,
  GetAccountingIntegrationsForExternalAppsAccordionQuery,
  GetCrmIntegrationsForExternalAppsAccordionQuery,
  GetTaxIntegrationsForExternalAppsAccordionQuery,
  HubspotIntegration,
  IntegrationTypeEnum,
  NetsuiteIntegration,
  SalesforceIntegration,
  XeroIntegration,
} from '~/generated/graphql'

import { integrationTypeToTypename } from './customerIntegrationConst'

type SupportedIntegration =
  | AnrokIntegration
  | AvalaraIntegration
  | HubspotIntegration
  | NetsuiteIntegration
  | SalesforceIntegration
  | XeroIntegration

export const getAllIntegrationForAnIntegrationType = <T extends SupportedIntegration>({
  integrationType,
  allIntegrationsData,
}: {
  integrationType: IntegrationTypeEnum
  allIntegrationsData?:
    | GetAccountingIntegrationsForExternalAppsAccordionQuery
    | GetTaxIntegrationsForExternalAppsAccordionQuery
    | GetCrmIntegrationsForExternalAppsAccordionQuery
}): T[] | undefined => {
  // Get all integrations of the same type
  return allIntegrationsData?.integrations?.collection.filter(
    (i) => i.__typename === integrationTypeToTypename[integrationType],
  ) as T[] | undefined
}
