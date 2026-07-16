import {
  AddCustomerDrawerFragment,
  AnrokIntegration,
  GetAccountingIntegrationsForExternalAppsAccordionQuery,
  GetCrmIntegrationsForExternalAppsAccordionQuery,
  GetTaxIntegrationsForExternalAppsAccordionQuery,
  HubspotIntegration,
  IntegrationTypeEnum,
  XeroIntegration,
} from '~/generated/graphql'
import { getAllIntegrationForAnIntegrationType } from '~/pages/createCustomers/common/getAllIntegrationForAnIntegrationType'

import { getIntegration } from '../getIntegration'

type IntegrationCustomer =
  | AddCustomerDrawerFragment['xeroCustomer']
  | AddCustomerDrawerFragment['netsuiteCustomer']
  | AddCustomerDrawerFragment['anrokCustomer']
  | AddCustomerDrawerFragment['avalaraCustomer']
  | AddCustomerDrawerFragment['hubspotCustomer']
  | AddCustomerDrawerFragment['salesforceCustomer']

// Mock the getAllIntegrationForAnIntegrationType function
jest.mock('~/pages/createCustomers/common/getAllIntegrationForAnIntegrationType', () => ({
  getAllIntegrationForAnIntegrationType: jest.fn(),
}))

describe('getIntegration', () => {
  const getAllIntegrationForAnIntegrationTypeMock = jest.requireMock(
    '~/pages/createCustomers/common/getAllIntegrationForAnIntegrationType',
  ).getAllIntegrationForAnIntegrationType

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('hadInitialIntegrationCustomer detection', () => {
    it('should return true when customer has existing integration of same type and integration still exists', () => {
      const integrationCustomers: Array<AddCustomerDrawerFragment['xeroCustomer']> = [
        {
          __typename: 'XeroCustomer',
          id: 'customer-1',
          integrationType: IntegrationTypeEnum.Xero,
          integrationId: 'integration-1',
          integrationCode: 'xero_code',
          externalCustomerId: 'ext-customer-1',
          syncWithProvider: true,
        },
      ]

      getAllIntegrationForAnIntegrationTypeMock.mockReturnValue([
        { __typename: 'XeroIntegration', id: 'xero-1', code: 'xero_code', name: 'Xero' },
      ])

      const result = getIntegration({
        integrationType: IntegrationTypeEnum.Xero,
        integrationCustomers,
        allIntegrationsData: undefined,
      })

      expect(result.hadInitialIntegrationCustomer).toBe(true)
    })

    it('should return false when customer has integration but it was deleted', () => {
      const integrationCustomers: Array<AddCustomerDrawerFragment['xeroCustomer']> = [
        {
          __typename: 'XeroCustomer',
          id: 'customer-1',
          integrationType: IntegrationTypeEnum.Xero,
          integrationId: 'integration-1',
          integrationCode: 'deleted_xero_code',
          externalCustomerId: 'ext-customer-1',
          syncWithProvider: true,
        },
      ]

      getAllIntegrationForAnIntegrationTypeMock.mockReturnValue([
        { __typename: 'XeroIntegration', id: 'xero-2', code: 'new_xero_code', name: 'New Xero' },
      ])

      const result = getIntegration({
        integrationType: IntegrationTypeEnum.Xero,
        integrationCustomers,
        allIntegrationsData: undefined,
      })

      expect(result.hadInitialIntegrationCustomer).toBe(false)
    })

    it('should return false when customer has no integration of same type', () => {
      const integrationCustomers: AddCustomerDrawerFragment['netsuiteCustomer'][] = [
        {
          __typename: 'NetsuiteCustomer',
          id: 'customer-1',
          integrationType: IntegrationTypeEnum.Netsuite,
          integrationId: 'integration-1',
          externalCustomerId: 'ext-customer-1',
          syncWithProvider: true,
        },
      ]

      getAllIntegrationForAnIntegrationTypeMock.mockReturnValue([])

      const result = getIntegration({
        integrationType: IntegrationTypeEnum.Xero, // Different type
        integrationCustomers,
        allIntegrationsData: undefined,
      })

      expect(result.hadInitialIntegrationCustomer).toBe(false)
    })

    it('should return false when integrationCustomers is undefined', () => {
      getAllIntegrationForAnIntegrationTypeMock.mockReturnValue([])

      const result = getIntegration({
        integrationType: IntegrationTypeEnum.Xero,
        integrationCustomers: undefined,
        allIntegrationsData: undefined,
      })

      expect(result.hadInitialIntegrationCustomer).toBe(false)
    })

    it('should return false when integrationCustomers is empty array', () => {
      getAllIntegrationForAnIntegrationTypeMock.mockReturnValue([])

      const result = getIntegration({
        integrationType: IntegrationTypeEnum.Xero,
        integrationCustomers: [],
        allIntegrationsData: undefined,
      })

      expect(result.hadInitialIntegrationCustomer).toBe(false)
    })

    it('should handle multiple integration customers and find matching type', () => {
      const integrationCustomers: Array<IntegrationCustomer> = [
        {
          __typename: 'NetsuiteCustomer',
          id: 'customer-1',
          integrationType: IntegrationTypeEnum.Netsuite,
          integrationId: 'integration-1',
          integrationCode: 'netsuite_code',
          externalCustomerId: 'ext-customer-1',
          syncWithProvider: true,
        },
        {
          __typename: 'XeroCustomer',
          id: 'customer-2',
          integrationType: IntegrationTypeEnum.Xero,
          integrationId: 'integration-2',
          integrationCode: 'xero_code',
          externalCustomerId: 'ext-customer-2',
          syncWithProvider: false,
        },
        {
          __typename: 'AnrokCustomer',
          id: 'customer-3',
          integrationType: IntegrationTypeEnum.Anrok,
          integrationId: 'integration-3',
          integrationCode: 'anrok_code',
          externalCustomerId: 'ext-customer-3',
          syncWithProvider: true,
        },
      ]

      getAllIntegrationForAnIntegrationTypeMock.mockReturnValue([
        { __typename: 'XeroIntegration', id: 'xero-1', code: 'xero_code', name: 'Xero' },
      ])

      const result = getIntegration({
        integrationType: IntegrationTypeEnum.Xero,
        integrationCustomers,
        allIntegrationsData: undefined,
      })

      expect(result.hadInitialIntegrationCustomer).toBe(true)
    })
  })

  describe('allIntegrations retrieval', () => {
    it('should call getAllIntegrationForAnIntegrationType with correct parameters', () => {
      const mockIntegrationsData: GetAccountingIntegrationsForExternalAppsAccordionQuery = {
        integrations: {
          collection: [
            {
              __typename: 'XeroIntegration',
              id: 'xero-1',
              name: 'Xero Integration',
              code: 'xero_code',
            } as XeroIntegration,
          ],
        },
      }

      const mockAllIntegrations = [
        {
          __typename: 'XeroIntegration',
          id: 'xero-1',
          name: 'Xero Integration',
          code: 'xero_code',
        } as XeroIntegration,
      ]

      getAllIntegrationForAnIntegrationTypeMock.mockReturnValue(mockAllIntegrations)

      const result = getIntegration<XeroIntegration>({
        integrationType: IntegrationTypeEnum.Xero,
        integrationCustomers: [],
        allIntegrationsData: mockIntegrationsData,
      })

      expect(getAllIntegrationForAnIntegrationTypeMock).toHaveBeenCalledWith({
        integrationType: IntegrationTypeEnum.Xero,
        allIntegrationsData: mockIntegrationsData,
      })

      expect(result.allIntegrations).toEqual(mockAllIntegrations)
    })

    it('should work with tax integrations data', () => {
      const mockIntegrationsData: GetTaxIntegrationsForExternalAppsAccordionQuery = {
        integrations: {
          collection: [
            {
              __typename: 'AnrokIntegration',
              id: 'anrok-1',
              name: 'Anrok Integration',
              code: 'anrok_code',
            } as AnrokIntegration,
          ],
        },
      }

      const mockAllIntegrations = [
        {
          __typename: 'AnrokIntegration',
          id: 'anrok-1',
          name: 'Anrok Integration',
          code: 'anrok_code',
        } as AnrokIntegration,
      ]

      getAllIntegrationForAnIntegrationTypeMock.mockReturnValue(mockAllIntegrations)

      const result = getIntegration<AnrokIntegration>({
        integrationType: IntegrationTypeEnum.Anrok,
        integrationCustomers: [],
        allIntegrationsData: mockIntegrationsData,
      })

      expect(getAllIntegrationForAnIntegrationTypeMock).toHaveBeenCalledWith({
        integrationType: IntegrationTypeEnum.Anrok,
        allIntegrationsData: mockIntegrationsData,
      })

      expect(result.allIntegrations).toEqual(mockAllIntegrations)
    })

    it('should work with CRM integrations data', () => {
      const mockIntegrationsData: GetCrmIntegrationsForExternalAppsAccordionQuery = {
        integrations: {
          collection: [
            {
              __typename: 'HubspotIntegration',
              id: 'hubspot-1',
              name: 'Hubspot Integration',
              code: 'hubspot_code',
            } as HubspotIntegration,
          ],
        },
      }

      const mockAllIntegrations = [
        {
          __typename: 'HubspotIntegration',
          id: 'hubspot-1',
          name: 'Hubspot Integration',
          code: 'hubspot_code',
        } as HubspotIntegration,
      ]

      getAllIntegrationForAnIntegrationTypeMock.mockReturnValue(mockAllIntegrations)

      const result = getIntegration<HubspotIntegration>({
        integrationType: IntegrationTypeEnum.Hubspot,
        integrationCustomers: [],
        allIntegrationsData: mockIntegrationsData,
      })

      expect(getAllIntegrationForAnIntegrationTypeMock).toHaveBeenCalledWith({
        integrationType: IntegrationTypeEnum.Hubspot,
        allIntegrationsData: mockIntegrationsData,
      })

      expect(result.allIntegrations).toEqual(mockAllIntegrations)
    })

    it('should work without allIntegrationsData', () => {
      getAllIntegrationForAnIntegrationTypeMock.mockReturnValue(undefined)

      const result = getIntegration({
        integrationType: IntegrationTypeEnum.Xero,
        integrationCustomers: [],
        allIntegrationsData: undefined,
      })

      expect(getAllIntegrationForAnIntegrationTypeMock).toHaveBeenCalledWith({
        integrationType: IntegrationTypeEnum.Xero,
        allIntegrationsData: undefined,
      })

      expect(result.allIntegrations).toBeUndefined()
    })
  })

  describe('integration types coverage', () => {
    const mapping: Array<[IntegrationTypeEnum, NonNullable<IntegrationCustomer>['__typename']]> = [
      [IntegrationTypeEnum.Xero, 'XeroCustomer'],
      [IntegrationTypeEnum.Netsuite, 'NetsuiteCustomer'],
      [IntegrationTypeEnum.Anrok, 'AnrokCustomer'],
      [IntegrationTypeEnum.Avalara, 'AvalaraCustomer'],
      [IntegrationTypeEnum.Hubspot, 'HubspotCustomer'],
      [IntegrationTypeEnum.Salesforce, 'SalesforceCustomer'],
    ]

    it.each(mapping)(
      'should work with %s integration type',
      (integrationType, expectedTypename) => {
        const integrationCustomers: Array<IntegrationCustomer> = [
          {
            __typename: expectedTypename,
            id: 'customer-1',
            integrationType,
            integrationId: 'integration-1',
            integrationCode: 'test_code',
            externalCustomerId: 'ext-customer-1',
            syncWithProvider: true,
          },
        ]

        getAllIntegrationForAnIntegrationTypeMock.mockReturnValue([
          {
            __typename: expectedTypename.replace('Customer', 'Integration'),
            id: 'int-1',
            code: 'test_code',
            name: 'Test',
          },
        ])

        const result = getIntegration({
          integrationType,
          integrationCustomers,
          allIntegrationsData: undefined,
        })

        expect(result.hadInitialIntegrationCustomer).toBe(true)
        expect(getAllIntegrationForAnIntegrationType).toHaveBeenCalledWith({
          integrationType,
          allIntegrationsData: undefined,
        })
      },
    )
  })

  describe('complete workflow scenarios', () => {
    it('should handle customer with existing integration and return all available integrations', () => {
      const integrationCustomers: AddCustomerDrawerFragment['xeroCustomer'][] = [
        {
          __typename: 'XeroCustomer',
          id: 'customer-1',
          integrationType: IntegrationTypeEnum.Xero,
          integrationId: 'integration-1',
          integrationCode: 'xero_code_1',
          externalCustomerId: 'ext-customer-1',
          syncWithProvider: true,
        },
      ]

      const mockIntegrationsData: GetAccountingIntegrationsForExternalAppsAccordionQuery = {
        integrations: {
          collection: [
            {
              __typename: 'XeroIntegration',
              id: 'xero-1',
              name: 'Xero Integration 1',
              code: 'xero_code_1',
            } as XeroIntegration,
            {
              __typename: 'XeroIntegration',
              id: 'xero-2',
              name: 'Xero Integration 2',
              code: 'xero_code_2',
            } as XeroIntegration,
          ],
        },
      }

      const mockAllIntegrations = [
        {
          __typename: 'XeroIntegration',
          id: 'xero-1',
          name: 'Xero Integration 1',
          code: 'xero_code_1',
        } as XeroIntegration,
        {
          __typename: 'XeroIntegration',
          id: 'xero-2',
          name: 'Xero Integration 2',
          code: 'xero_code_2',
        } as XeroIntegration,
      ]

      getAllIntegrationForAnIntegrationTypeMock.mockReturnValue(mockAllIntegrations)

      const result = getIntegration<XeroIntegration>({
        integrationType: IntegrationTypeEnum.Xero,
        integrationCustomers,
        allIntegrationsData: mockIntegrationsData,
      })

      expect(result.hadInitialIntegrationCustomer).toBe(true)
      expect(result.allIntegrations).toEqual(mockAllIntegrations)
      expect(result.allIntegrations).toHaveLength(2)
    })

    it('should handle new customer without existing integration', () => {
      const mockIntegrationsData: GetTaxIntegrationsForExternalAppsAccordionQuery = {
        integrations: {
          collection: [
            {
              __typename: 'AnrokIntegration',
              id: 'anrok-1',
              name: 'Anrok Integration',
              code: 'anrok_code',
            } as AnrokIntegration,
          ],
        },
      }

      const mockAllIntegrations = [
        {
          __typename: 'AnrokIntegration',
          id: 'anrok-1',
          name: 'Anrok Integration',
          code: 'anrok_code',
        } as AnrokIntegration,
      ]

      getAllIntegrationForAnIntegrationTypeMock.mockReturnValue(mockAllIntegrations)

      const result = getIntegration<AnrokIntegration>({
        integrationType: IntegrationTypeEnum.Anrok,
        integrationCustomers: [],
        allIntegrationsData: mockIntegrationsData,
      })

      expect(result.hadInitialIntegrationCustomer).toBe(false)
      expect(result.allIntegrations).toEqual(mockAllIntegrations)
    })
  })

  describe('edge cases', () => {
    it('should handle null integration customers gracefully', () => {
      const integrationCustomers = [
        null,
        {
          id: 'customer-1',
          integrationType: IntegrationTypeEnum.Xero,
          integrationId: 'integration-1',
          integrationCode: 'xero_code',
          externalCustomerId: 'ext-customer-1',
          syncWithProvider: true,
        },
        null,
      ] as Array<IntegrationCustomer | null>

      getAllIntegrationForAnIntegrationTypeMock.mockReturnValue([
        { __typename: 'XeroIntegration', id: 'xero-1', code: 'xero_code', name: 'Xero' },
      ])

      const result = getIntegration({
        integrationType: IntegrationTypeEnum.Xero,
        integrationCustomers,
        allIntegrationsData: undefined,
      })

      expect(result.hadInitialIntegrationCustomer).toBe(true)
    })

    it('should handle integration customers with undefined integrationType', () => {
      const integrationCustomers = [
        {
          id: 'customer-1',
          integrationType: undefined,
          integrationId: 'integration-1',
          externalCustomerId: 'ext-customer-1',
          syncWithProvider: true,
        },
      ] as Array<IntegrationCustomer>

      getAllIntegrationForAnIntegrationTypeMock.mockReturnValue([])

      const result = getIntegration({
        integrationType: IntegrationTypeEnum.Xero,
        integrationCustomers,
        allIntegrationsData: undefined,
      })

      expect(result.hadInitialIntegrationCustomer).toBe(false)
    })
  })
})
