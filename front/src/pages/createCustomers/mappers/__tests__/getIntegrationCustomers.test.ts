import {
  AnrokIntegration,
  AvalaraIntegration,
  GetAccountingIntegrationsForExternalAppsAccordionQuery,
  GetCrmIntegrationsForExternalAppsAccordionQuery,
  GetTaxIntegrationsForExternalAppsAccordionQuery,
  HubspotIntegration,
  HubspotTargetedObjectsEnum,
  IntegrationTypeEnum,
  NetsuiteIntegration,
  SalesforceIntegration,
  XeroIntegration,
} from '~/generated/graphql'
import { CreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'

import { getIntegrationCustomers } from '../getIntegrationCustomers'

// Mock the getAllIntegrationForAnIntegrationType function
jest.mock('~/pages/createCustomers/common/getAllIntegrationForAnIntegrationType', () => ({
  getAllIntegrationForAnIntegrationType: jest.fn(),
}))

describe('getIntegrationCustomers', () => {
  // Useful to specify return type or assert specific calls
  const getAllIntegrationForAnIntegrationTypeMock = jest.requireMock(
    '~/pages/createCustomers/common/getAllIntegrationForAnIntegrationType',
  ).getAllIntegrationForAnIntegrationType

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('when no provider codes are provided', () => {
    it('should return undefined', () => {
      const result = getIntegrationCustomers({})

      expect(result).toEqual([])
    })
  })

  describe('when provider codes are provided but no matching integrations found', () => {
    beforeEach(() => {
      // Mock getAllIntegrationForAnIntegrationType to return empty arrays
      getAllIntegrationForAnIntegrationTypeMock.mockReturnValue([])
    })

    it('should return empty array when tax provider not found', () => {
      const result = getIntegrationCustomers({
        taxProviderCode: 'non-existent-tax',
        taxProviders: {} as GetTaxIntegrationsForExternalAppsAccordionQuery,
      })

      expect(result).toEqual([])
    })

    it('should return empty array when accounting provider not found', () => {
      const result = getIntegrationCustomers({
        accountingProviderCode: 'non-existent-accounting',
        accountingProviders: {} as GetAccountingIntegrationsForExternalAppsAccordionQuery,
      })

      expect(result).toEqual([])
    })

    it('should return empty array when CRM provider not found', () => {
      const result = getIntegrationCustomers({
        crmProviderCode: 'non-existent-crm',
        crmProviders: {} as GetCrmIntegrationsForExternalAppsAccordionQuery,
      })

      expect(result).toEqual([])
    })
  })

  describe('when tax provider integration is found', () => {
    const mockAnrokIntegration: AnrokIntegration = {
      __typename: 'AnrokIntegration',
      id: 'anrok-1',
      code: 'anrok-test',
      name: 'Anrok Test',
      apiKey: 'anrok-api-key',
    }

    const mockAvalaraIntegration: AvalaraIntegration = {
      __typename: 'AvalaraIntegration',
      id: 'avalara-1',
      code: 'avalara-test',
      name: 'Avalara Test',
      companyCode: 'avalara-company',
      licenseKey: 'avalara-license',
    }

    beforeEach(() => {
      getAllIntegrationForAnIntegrationTypeMock.mockImplementation(
        ({ integrationType }: { integrationType: IntegrationTypeEnum }) => {
          if (integrationType === IntegrationTypeEnum.Anrok) {
            return [mockAnrokIntegration]
          }
          if (integrationType === IntegrationTypeEnum.Avalara) {
            return [mockAvalaraIntegration]
          }
          return []
        },
      )
    })

    it('should return Anrok integration customer with minimal data', () => {
      const result = getIntegrationCustomers({
        taxProviderCode: 'anrok-test',
        taxProviders: {} as GetTaxIntegrationsForExternalAppsAccordionQuery,
      })

      expect(result).toEqual([
        {
          integrationCode: 'anrok-test',
          integrationType: IntegrationTypeEnum.Anrok,
          syncWithProvider: undefined,
          externalCustomerId: undefined,
        },
      ])
    })

    it('should return Anrok integration customer with full tax customer data', () => {
      const taxCustomer: CreateCustomerDefaultValues['taxCustomer'] = {
        syncWithProvider: true,
        taxCustomerId: 'tax-123',
      }

      const result = getIntegrationCustomers({
        taxProviderCode: 'anrok-test',
        taxProviders: {} as GetTaxIntegrationsForExternalAppsAccordionQuery,
        taxCustomer,
      })

      expect(result).toEqual([
        {
          integrationCode: 'anrok-test',
          integrationType: IntegrationTypeEnum.Anrok,
          syncWithProvider: true,
          externalCustomerId: 'tax-123',
        },
      ])
    })

    it('should return Avalara integration customer', () => {
      const taxCustomer: CreateCustomerDefaultValues['taxCustomer'] = {
        syncWithProvider: false,
        taxCustomerId: 'avalara-456',
      }

      const result = getIntegrationCustomers({
        taxProviderCode: 'avalara-test',
        taxProviders: {} as GetTaxIntegrationsForExternalAppsAccordionQuery,
        taxCustomer,
      })

      expect(result).toEqual([
        {
          integrationCode: 'avalara-test',
          integrationType: IntegrationTypeEnum.Avalara,
          syncWithProvider: false,
          externalCustomerId: 'avalara-456',
        },
      ])
    })
  })

  describe('when accounting provider integration is found', () => {
    const mockNetsuiteIntegration: NetsuiteIntegration = {
      __typename: 'NetsuiteIntegration',
      id: 'netsuite-1',
      code: 'netsuite-test',
      name: 'NetSuite Test',
      connectionId: 'netsuite-conn-123',
      scriptEndpointUrl: 'https://netsuite.example.com/endpoint',
    }

    const mockXeroIntegration: XeroIntegration = {
      __typename: 'XeroIntegration',
      id: 'xero-1',
      code: 'xero-test',
      name: 'Xero Test',
      connectionId: 'xero-conn-456',
    }

    beforeEach(() => {
      getAllIntegrationForAnIntegrationTypeMock.mockImplementation(
        ({ integrationType }: { integrationType: IntegrationTypeEnum }) => {
          if (integrationType === IntegrationTypeEnum.Netsuite) {
            return [mockNetsuiteIntegration]
          }
          if (integrationType === IntegrationTypeEnum.Xero) {
            return [mockXeroIntegration]
          }
          return []
        },
      )
    })

    it('should return NetSuite integration customer with minimal data', () => {
      const result = getIntegrationCustomers({
        accountingProviderCode: 'netsuite-test',
        accountingProviders: {} as GetAccountingIntegrationsForExternalAppsAccordionQuery,
      })

      expect(result).toEqual([
        {
          integrationCode: 'netsuite-test',
          integrationType: IntegrationTypeEnum.Netsuite,
          syncWithProvider: undefined,
          externalCustomerId: undefined,
        },
      ])
    })

    it('should return NetSuite integration customer with full accounting customer data', () => {
      const accountingCustomer: CreateCustomerDefaultValues['accountingCustomer'] = {
        syncWithProvider: true,
        accountingCustomerId: 'netsuite-123',
        subsidiaryId: 'subsidiary-456',
      }

      const result = getIntegrationCustomers({
        accountingProviderCode: 'netsuite-test',
        accountingProviders: {} as GetAccountingIntegrationsForExternalAppsAccordionQuery,
        accountingCustomer,
      })

      expect(result).toEqual([
        {
          integrationCode: 'netsuite-test',
          integrationType: IntegrationTypeEnum.Netsuite,
          syncWithProvider: true,
          externalCustomerId: 'netsuite-123',
          subsidiaryId: 'subsidiary-456',
        },
      ])
    })

    it('should return accounting customer without subsidiaryId when not provided', () => {
      const accountingCustomer: CreateCustomerDefaultValues['accountingCustomer'] = {
        syncWithProvider: false,
        accountingCustomerId: 'xero-789',
      }

      const result = getIntegrationCustomers({
        accountingProviderCode: 'xero-test',
        accountingProviders: {} as GetAccountingIntegrationsForExternalAppsAccordionQuery,
        accountingCustomer,
      })

      expect(result).toEqual([
        {
          integrationCode: 'xero-test',
          integrationType: IntegrationTypeEnum.Xero,
          syncWithProvider: false,
          externalCustomerId: 'xero-789',
        },
      ])
    })
  })

  describe('when CRM provider integration is found', () => {
    const mockHubspotIntegration: HubspotIntegration = {
      __typename: 'HubspotIntegration',
      id: 'hubspot-1',
      code: 'hubspot-test',
      name: 'HubSpot Test',
      connectionId: 'hubspot-conn-789',
      defaultTargetedObject: HubspotTargetedObjectsEnum.Contacts,
    }

    const mockSalesforceIntegration: SalesforceIntegration = {
      __typename: 'SalesforceIntegration',
      id: 'salesforce-1',
      code: 'salesforce-test',
      name: 'Salesforce Test',
      instanceId: 'salesforce-inst-101',
    }

    beforeEach(() => {
      getAllIntegrationForAnIntegrationTypeMock.mockImplementation(
        ({ integrationType }: { integrationType: IntegrationTypeEnum }) => {
          if (integrationType === IntegrationTypeEnum.Hubspot) {
            return [mockHubspotIntegration]
          }
          if (integrationType === IntegrationTypeEnum.Salesforce) {
            return [mockSalesforceIntegration]
          }
          return []
        },
      )
    })

    it('should return HubSpot integration customer with minimal data', () => {
      const result = getIntegrationCustomers({
        crmProviderCode: 'hubspot-test',
        crmProviders: {} as GetCrmIntegrationsForExternalAppsAccordionQuery,
      })

      expect(result).toEqual([
        {
          integrationCode: 'hubspot-test',
          integrationType: IntegrationTypeEnum.Hubspot,
          syncWithProvider: undefined,
          externalCustomerId: undefined,
        },
      ])
    })

    it('should return HubSpot integration customer with full CRM customer data', () => {
      const crmCustomer: CreateCustomerDefaultValues['crmCustomer'] = {
        syncWithProvider: true,
        crmCustomerId: 'hubspot-123',
        targetedObject: HubspotTargetedObjectsEnum.Companies,
      }

      const result = getIntegrationCustomers({
        crmProviderCode: 'hubspot-test',
        crmProviders: {} as GetCrmIntegrationsForExternalAppsAccordionQuery,
        crmCustomer,
      })

      expect(result).toEqual([
        {
          integrationCode: 'hubspot-test',
          integrationType: IntegrationTypeEnum.Hubspot,
          syncWithProvider: true,
          externalCustomerId: 'hubspot-123',
          targetedObject: HubspotTargetedObjectsEnum.Companies,
        },
      ])
    })

    it('should return Salesforce integration customer without targetedObject', () => {
      const crmCustomer: CreateCustomerDefaultValues['crmCustomer'] = {
        syncWithProvider: false,
        crmCustomerId: 'salesforce-456',
      }

      const result = getIntegrationCustomers({
        crmProviderCode: 'salesforce-test',
        crmProviders: {} as GetCrmIntegrationsForExternalAppsAccordionQuery,
        crmCustomer,
      })

      expect(result).toEqual([
        {
          integrationCode: 'salesforce-test',
          integrationType: IntegrationTypeEnum.Salesforce,
          syncWithProvider: false,
          externalCustomerId: 'salesforce-456',
        },
      ])
    })
  })

  describe('when multiple provider integrations are found', () => {
    const mockAnrokIntegration: AnrokIntegration = {
      __typename: 'AnrokIntegration',
      id: 'anrok-1',
      code: 'anrok-test',
      name: 'Anrok Test',
      apiKey: 'anrok-api-key',
    }

    const mockNetsuiteIntegration: NetsuiteIntegration = {
      __typename: 'NetsuiteIntegration',
      id: 'netsuite-1',
      code: 'netsuite-test',
      name: 'NetSuite Test',
      connectionId: 'netsuite-conn-123',
      scriptEndpointUrl: 'https://netsuite.example.com/endpoint',
    }

    const mockHubspotIntegration: HubspotIntegration = {
      __typename: 'HubspotIntegration',
      id: 'hubspot-1',
      code: 'hubspot-test',
      name: 'HubSpot Test',
      connectionId: 'hubspot-conn-789',
      defaultTargetedObject: HubspotTargetedObjectsEnum.Contacts,
    }

    beforeEach(() => {
      getAllIntegrationForAnIntegrationTypeMock.mockImplementation(
        ({ integrationType }: { integrationType: IntegrationTypeEnum }) => {
          if (integrationType === IntegrationTypeEnum.Anrok) {
            return [mockAnrokIntegration]
          }
          if (integrationType === IntegrationTypeEnum.Netsuite) {
            return [mockNetsuiteIntegration]
          }
          if (integrationType === IntegrationTypeEnum.Hubspot) {
            return [mockHubspotIntegration]
          }
          return []
        },
      )
    })

    it('should return all integration customers when all providers are found', () => {
      const taxCustomer: CreateCustomerDefaultValues['taxCustomer'] = {
        syncWithProvider: true,
        taxCustomerId: 'tax-123',
      }

      const accountingCustomer: CreateCustomerDefaultValues['accountingCustomer'] = {
        syncWithProvider: false,
        accountingCustomerId: 'accounting-456',
        subsidiaryId: 'sub-789',
      }

      const crmCustomer: CreateCustomerDefaultValues['crmCustomer'] = {
        syncWithProvider: true,
        crmCustomerId: 'crm-101',
        targetedObject: HubspotTargetedObjectsEnum.Contacts,
      }

      const result = getIntegrationCustomers({
        taxProviderCode: 'anrok-test',
        accountingProviderCode: 'netsuite-test',
        crmProviderCode: 'hubspot-test',
        taxProviders: {} as GetTaxIntegrationsForExternalAppsAccordionQuery,
        accountingProviders: {} as GetAccountingIntegrationsForExternalAppsAccordionQuery,
        crmProviders: {} as GetCrmIntegrationsForExternalAppsAccordionQuery,
        taxCustomer,
        accountingCustomer,
        crmCustomer,
      })

      expect(result).toEqual([
        {
          integrationCode: 'anrok-test',
          integrationType: IntegrationTypeEnum.Anrok,
          syncWithProvider: true,
          externalCustomerId: 'tax-123',
        },
        {
          integrationCode: 'netsuite-test',
          integrationType: IntegrationTypeEnum.Netsuite,
          syncWithProvider: false,
          externalCustomerId: 'accounting-456',
          subsidiaryId: 'sub-789',
        },
        {
          integrationCode: 'hubspot-test',
          integrationType: IntegrationTypeEnum.Hubspot,
          syncWithProvider: true,
          externalCustomerId: 'crm-101',
          targetedObject: HubspotTargetedObjectsEnum.Contacts,
        },
      ])
    })

    it('should return only found integration customers when some providers are not found', () => {
      const taxCustomer: CreateCustomerDefaultValues['taxCustomer'] = {
        syncWithProvider: true,
        taxCustomerId: 'tax-123',
      }

      const result = getIntegrationCustomers({
        taxProviderCode: 'anrok-test',
        accountingProviderCode: 'non-existent-accounting',
        crmProviderCode: 'non-existent-crm',
        taxProviders: {} as GetTaxIntegrationsForExternalAppsAccordionQuery,
        accountingProviders: {} as GetAccountingIntegrationsForExternalAppsAccordionQuery,
        crmProviders: {} as GetCrmIntegrationsForExternalAppsAccordionQuery,
        taxCustomer,
      })

      expect(result).toEqual([
        {
          integrationCode: 'anrok-test',
          integrationType: IntegrationTypeEnum.Anrok,
          syncWithProvider: true,
          externalCustomerId: 'tax-123',
        },
      ])
    })
  })

  describe('edge cases', () => {
    it('should handle undefined customer objects gracefully', () => {
      const mockAnrokIntegration: AnrokIntegration = {
        __typename: 'AnrokIntegration',
        id: 'anrok-1',
        code: 'anrok-test',
        name: 'Anrok Test',
        apiKey: 'anrok-api-key',
      }

      getAllIntegrationForAnIntegrationTypeMock.mockImplementation(
        ({ integrationType }: { integrationType: IntegrationTypeEnum }) => {
          if (integrationType === IntegrationTypeEnum.Anrok) {
            return [mockAnrokIntegration]
          }
          return []
        },
      )

      const result = getIntegrationCustomers({
        taxProviderCode: 'anrok-test',
        taxProviders: {} as GetTaxIntegrationsForExternalAppsAccordionQuery,
        taxCustomer: undefined,
      })

      expect(result).toEqual([
        {
          integrationCode: 'anrok-test',
          integrationType: IntegrationTypeEnum.Anrok,
          syncWithProvider: undefined,
          externalCustomerId: undefined,
        },
      ])
    })

    it('should handle empty subsidiaryId and targetedObject values', () => {
      const mockNetsuiteIntegration: NetsuiteIntegration = {
        __typename: 'NetsuiteIntegration',
        id: 'netsuite-1',
        code: 'netsuite-test',
        name: 'NetSuite Test',
        connectionId: 'netsuite-conn-123',
        scriptEndpointUrl: 'https://netsuite.example.com/endpoint',
      }

      const mockHubspotIntegration: HubspotIntegration = {
        __typename: 'HubspotIntegration',
        id: 'hubspot-1',
        code: 'hubspot-test',
        name: 'HubSpot Test',
        connectionId: 'hubspot-conn-789',
        defaultTargetedObject: HubspotTargetedObjectsEnum.Contacts,
      }

      getAllIntegrationForAnIntegrationTypeMock.mockImplementation(
        ({ integrationType }: { integrationType: IntegrationTypeEnum }) => {
          if (integrationType === IntegrationTypeEnum.Netsuite) {
            return [mockNetsuiteIntegration]
          }
          if (integrationType === IntegrationTypeEnum.Hubspot) {
            return [mockHubspotIntegration]
          }
          return []
        },
      )

      const accountingCustomer: CreateCustomerDefaultValues['accountingCustomer'] = {
        syncWithProvider: true,
        accountingCustomerId: 'netsuite-123',
        subsidiaryId: '', // Empty string
      }

      const crmCustomer: CreateCustomerDefaultValues['crmCustomer'] = {
        syncWithProvider: true,
        crmCustomerId: 'hubspot-456',
        targetedObject: undefined, // Undefined
      }

      const result = getIntegrationCustomers({
        accountingProviderCode: 'netsuite-test',
        crmProviderCode: 'hubspot-test',
        accountingProviders: {} as GetAccountingIntegrationsForExternalAppsAccordionQuery,
        crmProviders: {} as GetCrmIntegrationsForExternalAppsAccordionQuery,
        accountingCustomer,
        crmCustomer,
      })

      expect(result).toEqual([
        {
          integrationCode: 'netsuite-test',
          integrationType: IntegrationTypeEnum.Netsuite,
          syncWithProvider: true,
          externalCustomerId: 'netsuite-123',
          // subsidiaryId should not be included when empty
        },
        {
          integrationCode: 'hubspot-test',
          integrationType: IntegrationTypeEnum.Hubspot,
          syncWithProvider: true,
          externalCustomerId: 'hubspot-456',
          // targetedObject should not be included when undefined
        },
      ])
    })
  })
})
