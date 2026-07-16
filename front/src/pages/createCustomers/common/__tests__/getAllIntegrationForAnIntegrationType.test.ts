import { IntegrationTypeEnum } from '~/generated/graphql'

import { getAllIntegrationForAnIntegrationType } from '../getAllIntegrationForAnIntegrationType'

describe('getAllIntegrationForAnIntegrationType', () => {
  describe('when filtering accounting integrations', () => {
    const mockAccountingIntegrationsData = {
      integrations: {
        collection: [
          {
            __typename: 'NetsuiteIntegration' as const,
            id: '1',
            code: 'netsuite-1',
            name: 'Netsuite Production',
          },
          {
            __typename: 'XeroIntegration' as const,
            id: '2',
            code: 'xero-1',
            name: 'Xero Integration',
          },
          {
            __typename: 'AnrokIntegration' as const,
            id: '3',
            code: 'anrok-1',
            name: 'Anrok Tax',
          },
          {
            __typename: 'NetsuiteIntegration' as const,
            id: '4',
            code: 'netsuite-2',
            name: 'Netsuite Sandbox',
          },
        ],
      },
    }

    it('should return all Netsuite integrations when filtering by Netsuite type', () => {
      const result = getAllIntegrationForAnIntegrationType({
        integrationType: IntegrationTypeEnum.Netsuite,
        allIntegrationsData: mockAccountingIntegrationsData,
      })

      expect(result).toEqual([
        {
          __typename: 'NetsuiteIntegration',
          id: '1',
          code: 'netsuite-1',
          name: 'Netsuite Production',
        },
        {
          __typename: 'NetsuiteIntegration',
          id: '4',
          code: 'netsuite-2',
          name: 'Netsuite Sandbox',
        },
      ])
    })

    it('should return all Xero integrations when filtering by Xero type', () => {
      const result = getAllIntegrationForAnIntegrationType({
        integrationType: IntegrationTypeEnum.Xero,
        allIntegrationsData: mockAccountingIntegrationsData,
      })

      expect(result).toEqual([
        {
          __typename: 'XeroIntegration',
          id: '2',
          code: 'xero-1',
          name: 'Xero Integration',
        },
      ])
    })

    it('should return empty array when no integrations match the type', () => {
      const result = getAllIntegrationForAnIntegrationType({
        integrationType: IntegrationTypeEnum.Hubspot,
        allIntegrationsData: mockAccountingIntegrationsData,
      })

      expect(result).toEqual([])
    })
  })

  describe('when filtering tax integrations', () => {
    const mockTaxIntegrationsData = {
      integrations: {
        collection: [
          {
            __typename: 'AnrokIntegration' as const,
            id: '1',
            code: 'anrok-prod',
            name: 'Anrok Production',
          },
          {
            __typename: 'AvalaraIntegration' as const,
            id: '2',
            code: 'avalara-1',
            name: 'Avalara Tax',
          },
          {
            __typename: 'AnrokIntegration' as const,
            id: '3',
            code: 'anrok-dev',
            name: 'Anrok Development',
          },
          {
            __typename: 'NetsuiteIntegration' as const,
            id: '4',
            code: 'netsuite-1',
            name: 'Netsuite Integration',
          },
        ],
      },
    }

    it('should return all Anrok integrations when filtering by Anrok type', () => {
      const result = getAllIntegrationForAnIntegrationType({
        integrationType: IntegrationTypeEnum.Anrok,
        allIntegrationsData: mockTaxIntegrationsData,
      })

      expect(result).toEqual([
        {
          __typename: 'AnrokIntegration',
          id: '1',
          code: 'anrok-prod',
          name: 'Anrok Production',
        },
        {
          __typename: 'AnrokIntegration',
          id: '3',
          code: 'anrok-dev',
          name: 'Anrok Development',
        },
      ])
    })

    it('should return all Avalara integrations when filtering by Avalara type', () => {
      const result = getAllIntegrationForAnIntegrationType({
        integrationType: IntegrationTypeEnum.Avalara,
        allIntegrationsData: mockTaxIntegrationsData,
      })

      expect(result).toEqual([
        {
          __typename: 'AvalaraIntegration',
          id: '2',
          code: 'avalara-1',
          name: 'Avalara Tax',
        },
      ])
    })
  })

  describe('when filtering CRM integrations', () => {
    const mockCrmIntegrationsData = {
      integrations: {
        collection: [
          {
            __typename: 'HubspotIntegration' as const,
            id: '1',
            code: 'hubspot-1',
            name: 'Hubspot CRM',
            defaultTargetedObject: 'COMPANIES' as const,
          },
          {
            __typename: 'SalesforceIntegration' as const,
            id: '2',
            code: 'salesforce-1',
            name: 'Salesforce Production',
          },
          {
            __typename: 'HubspotIntegration' as const,
            id: '3',
            code: 'hubspot-2',
            name: 'Hubspot Sandbox',
            defaultTargetedObject: 'CONTACTS' as const,
          },
        ],
      },
    }

    it('should return all Hubspot integrations when filtering by Hubspot type', () => {
      const result = getAllIntegrationForAnIntegrationType({
        integrationType: IntegrationTypeEnum.Hubspot,
        allIntegrationsData: mockCrmIntegrationsData,
      })

      expect(result).toEqual([
        {
          __typename: 'HubspotIntegration',
          id: '1',
          code: 'hubspot-1',
          name: 'Hubspot CRM',
          defaultTargetedObject: 'COMPANIES',
        },
        {
          __typename: 'HubspotIntegration',
          id: '3',
          code: 'hubspot-2',
          name: 'Hubspot Sandbox',
          defaultTargetedObject: 'CONTACTS',
        },
      ])
    })

    it('should return all Salesforce integrations when filtering by Salesforce type', () => {
      const result = getAllIntegrationForAnIntegrationType({
        integrationType: IntegrationTypeEnum.Salesforce,
        allIntegrationsData: mockCrmIntegrationsData,
      })

      expect(result).toEqual([
        {
          __typename: 'SalesforceIntegration',
          id: '2',
          code: 'salesforce-1',
          name: 'Salesforce Production',
        },
      ])
    })
  })

  describe('when handling edge cases', () => {
    it('should return undefined when allIntegrationsData is undefined', () => {
      const result = getAllIntegrationForAnIntegrationType({
        integrationType: IntegrationTypeEnum.Netsuite,
        allIntegrationsData: undefined,
      })

      expect(result).toBeUndefined()
    })

    it('should return undefined when integrations is null', () => {
      const result = getAllIntegrationForAnIntegrationType({
        integrationType: IntegrationTypeEnum.Netsuite,
        allIntegrationsData: { integrations: null },
      })

      expect(result).toBeUndefined()
    })

    it('should return empty array when collection is empty', () => {
      const result = getAllIntegrationForAnIntegrationType({
        integrationType: IntegrationTypeEnum.Netsuite,
        allIntegrationsData: {
          integrations: {
            collection: [],
          },
        },
      })

      expect(result).toEqual([])
    })

    it('should return empty array when no integrations match the type in a mixed collection', () => {
      const mixedData = {
        integrations: {
          collection: [
            {
              __typename: 'NetsuiteIntegration' as const,
              id: '1',
              code: 'netsuite-1',
              name: 'Netsuite Integration',
            },
            {
              __typename: 'XeroIntegration' as const,
              id: '2',
              code: 'xero-1',
              name: 'Xero Integration',
            },
          ],
        },
      }

      const result = getAllIntegrationForAnIntegrationType({
        integrationType: IntegrationTypeEnum.Anrok,
        allIntegrationsData: mixedData,
      })

      expect(result).toEqual([])
    })
  })

  describe('type safety', () => {
    it('should maintain proper TypeScript typing for returned integrations', () => {
      const mockData = {
        integrations: {
          collection: [
            {
              __typename: 'NetsuiteIntegration' as const,
              id: '1',
              code: 'netsuite-1',
              name: 'Netsuite Integration',
            },
          ],
        },
      }

      const result = getAllIntegrationForAnIntegrationType({
        integrationType: IntegrationTypeEnum.Netsuite,
        allIntegrationsData: mockData,
      })

      // This test ensures TypeScript compilation passes with correct types
      expect(result).toBeDefined()
      expect(Array.isArray(result)).toBe(true)
      if (result && result.length > 0) {
        expect(result[0].__typename).toBe('NetsuiteIntegration')
        expect(typeof result[0].id).toBe('string')
        expect(typeof result[0].code).toBe('string')
        expect(typeof result[0].name).toBe('string')
      }
    })
  })
})
