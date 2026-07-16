import { wait } from '@apollo/client/testing'
import { act, renderHook } from '@testing-library/react'
import React from 'react'

import { GetCrmIntegrationsForExternalAppsAccordionDocument } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { useCrmProviders } from '../useCrmProviders'

type PrepareType = {
  mockData?: Record<string, unknown>
  error?: boolean
  delay?: number
  networkError?: boolean
}

async function prepare({
  mockData,
  error = false,
  delay = 0,
  networkError = false,
}: PrepareType = {}) {
  const defaultMockData = {
    integrations: {
      collection: [
        {
          __typename: 'HubspotIntegration',
          id: '1',
          code: 'hubspot-main',
          name: 'Hubspot CRM',
          defaultTargetedObject: 'COMPANIES',
        },
        {
          __typename: 'SalesforceIntegration',
          id: '2',
          code: 'salesforce-prod',
          name: 'Salesforce Production',
        },
        {
          __typename: 'HubspotIntegration',
          id: '3',
          code: 'hubspot-sandbox',
          name: 'Hubspot Sandbox',
          defaultTargetedObject: 'CONTACTS',
        },
      ],
    },
  }

  const mocks = [
    {
      request: {
        query: GetCrmIntegrationsForExternalAppsAccordionDocument,
        variables: { limit: 1000 },
      },
      result: error
        ? {
            errors: [{ message: 'GraphQL error occurred' }],
          }
        : {
            data: mockData || defaultMockData,
          },
      delay,
      ...(networkError && { error: new Error('Network error') }),
    },
  ]

  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({
      children,
      mocks,
      forceTypenames: true,
    })

  const { result } = renderHook(() => useCrmProviders(), {
    wrapper: customWrapper,
  })

  return { result }
}

describe('useCrmProviders', () => {
  describe('when query succeeds with data', () => {
    it('should return CRM providers data and loading state', async () => {
      const { result } = await prepare()

      // Initially loading
      expect(result.current.isLoadingCrmProviders).toBe(true)
      expect(result.current.crmProviders).toBeUndefined()

      // Wait for the query to resolve
      await act(() => wait(0))

      // After loading completes
      expect(result.current.isLoadingCrmProviders).toBe(false)
      expect(result.current.crmProviders).toBeDefined()
      expect(result.current.crmProviders?.integrations?.collection).toHaveLength(3)

      const collection = result.current.crmProviders?.integrations?.collection

      expect(collection?.[0]).toEqual({
        __typename: 'HubspotIntegration',
        id: '1',
        code: 'hubspot-main',
        name: 'Hubspot CRM',
        defaultTargetedObject: 'COMPANIES',
      })
      expect(collection?.[1]).toEqual({
        __typename: 'SalesforceIntegration',
        id: '2',
        code: 'salesforce-prod',
        name: 'Salesforce Production',
      })
      expect(collection?.[2]).toEqual({
        __typename: 'HubspotIntegration',
        id: '3',
        code: 'hubspot-sandbox',
        name: 'Hubspot Sandbox',
        defaultTargetedObject: 'CONTACTS',
      })
    })

    it('should handle empty integrations collection', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: {
            collection: [],
          },
        },
      })

      await act(() => wait(0))

      expect(result.current.isLoadingCrmProviders).toBe(false)
      expect(result.current.crmProviders?.integrations?.collection).toEqual([])
    })

    it('should handle null integrations', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: null,
        },
      })

      await act(() => wait(0))

      expect(result.current.isLoadingCrmProviders).toBe(false)
      expect(result.current.crmProviders?.integrations).toBeNull()
    })

    it('should handle only Hubspot integrations', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: {
            collection: [
              {
                __typename: 'HubspotIntegration',
                id: '1',
                code: 'hubspot-only',
                name: 'Hubspot Only',
                defaultTargetedObject: 'COMPANIES',
              },
            ],
          },
        },
      })

      await act(() => wait(0))

      expect(result.current.isLoadingCrmProviders).toBe(false)
      expect(result.current.crmProviders?.integrations?.collection).toHaveLength(1)
      expect(result.current.crmProviders?.integrations?.collection?.[0]).toEqual({
        __typename: 'HubspotIntegration',
        id: '1',
        code: 'hubspot-only',
        name: 'Hubspot Only',
        defaultTargetedObject: 'COMPANIES',
      })
    })

    it('should handle only Salesforce integrations', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: {
            collection: [
              {
                __typename: 'SalesforceIntegration',
                id: '1',
                code: 'salesforce-only',
                name: 'Salesforce Only',
              },
            ],
          },
        },
      })

      await act(() => wait(0))

      expect(result.current.isLoadingCrmProviders).toBe(false)
      expect(result.current.crmProviders?.integrations?.collection).toHaveLength(1)
      expect(result.current.crmProviders?.integrations?.collection?.[0]).toEqual({
        __typename: 'SalesforceIntegration',
        id: '1',
        code: 'salesforce-only',
        name: 'Salesforce Only',
      })
    })

    it('should handle different defaultTargetedObject values for Hubspot', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: {
            collection: [
              {
                __typename: 'HubspotIntegration',
                id: '1',
                code: 'hubspot-companies',
                name: 'Hubspot for Companies',
                defaultTargetedObject: 'COMPANIES',
              },
              {
                __typename: 'HubspotIntegration',
                id: '2',
                code: 'hubspot-contacts',
                name: 'Hubspot for Contacts',
                defaultTargetedObject: 'CONTACTS',
              },
            ],
          },
        },
      })

      await act(() => wait(0))

      const collection = result.current.crmProviders?.integrations?.collection

      expect(collection).toHaveLength(2)
      expect(collection?.[0]).toMatchObject({
        defaultTargetedObject: 'COMPANIES',
      })
      expect(collection?.[1]).toMatchObject({
        defaultTargetedObject: 'CONTACTS',
      })
    })
  })

  describe('when query fails', () => {
    it('should handle GraphQL errors', async () => {
      const { result } = await prepare({ error: true })

      expect(result.current.isLoadingCrmProviders).toBe(true)

      await act(() => wait(0))

      expect(result.current.isLoadingCrmProviders).toBe(false)
      expect(result.current.crmProviders).toBeUndefined()
    })

    it('should handle network errors', async () => {
      const { result } = await prepare({ networkError: true })

      expect(result.current.isLoadingCrmProviders).toBe(true)

      await act(() => wait(0))

      expect(result.current.isLoadingCrmProviders).toBe(false)
      expect(result.current.crmProviders).toBeUndefined()
    })
  })

  describe('query configuration', () => {
    it('should use correct variables with limit of 1000', async () => {
      const { result } = await prepare()

      expect(result.current.isLoadingCrmProviders).toBe(true)

      await act(() => wait(0))

      expect(result.current.isLoadingCrmProviders).toBe(false)
      // The mock configuration verifies that variables: { limit: 1000 } is used
    })
  })

  describe('return value structure', () => {
    it('should return an object with crmProviders and isLoadingCrmProviders and getCrmProviderFromCode', async () => {
      const { result } = await prepare()

      expect(typeof result.current).toBe('object')
      expect('crmProviders' in result.current).toBe(true)
      expect('isLoadingCrmProviders' in result.current).toBe(true)
      expect('getCrmProviderFromCode' in result.current).toBe(true)
      expect(Object.keys(result.current)).toHaveLength(3)

      await act(() => wait(0))

      expect(typeof result.current.crmProviders).toBe('object')
      expect(typeof result.current.isLoadingCrmProviders).toBe('boolean')
    })
  })

  describe('integration with GraphQL fragments', () => {
    it('should properly handle HubspotIntegration fragment fields', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: {
            collection: [
              {
                __typename: 'HubspotIntegration',
                id: 'hubspot-1',
                code: 'HUBSPOT_PROD',
                name: 'Hubspot Production Environment',
                defaultTargetedObject: 'COMPANIES',
              },
            ],
          },
        },
      })

      await act(() => wait(0))

      const hubspotIntegration = result.current.crmProviders?.integrations?.collection?.[0]

      if (!hubspotIntegration || !('id' in hubspotIntegration)) {
        throw new Error('Hubspot integration not found in the result')
      }

      expect(hubspotIntegration.__typename).toBe('HubspotIntegration')
      expect(hubspotIntegration.id).toBe('hubspot-1')
      expect(hubspotIntegration.code).toBe('HUBSPOT_PROD')
      expect(hubspotIntegration.name).toBe('Hubspot Production Environment')
      expect('defaultTargetedObject' in hubspotIntegration).toBe(true)
      if ('defaultTargetedObject' in hubspotIntegration) {
        expect(hubspotIntegration.defaultTargetedObject).toBe('COMPANIES')
      }
    })

    it('should properly handle SalesforceIntegration fragment fields', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: {
            collection: [
              {
                __typename: 'SalesforceIntegration',
                id: 'salesforce-1',
                code: 'SALESFORCE_MAIN',
                name: 'Salesforce Main Account',
              },
            ],
          },
        },
      })

      await act(() => wait(0))

      const salesforceIntegration = result.current.crmProviders?.integrations?.collection?.[0]

      if (!salesforceIntegration || !('id' in salesforceIntegration)) {
        throw new Error('Salesforce integration not found in the result')
      }

      expect(salesforceIntegration.__typename).toBe('SalesforceIntegration')
      expect(salesforceIntegration.id).toBe('salesforce-1')
      expect(salesforceIntegration.code).toBe('SALESFORCE_MAIN')
      expect(salesforceIntegration.name).toBe('Salesforce Main Account')
    })
  })

  describe('getCrmProviderFromCode', () => {
    describe('when data is loaded', () => {
      it('should return correct provider type for Hubspot integration', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        const providerType = result.current.getCrmProviderFromCode('hubspot-main')

        expect(providerType).toBe('hubspot')
      })

      it('should return correct provider type for Salesforce integration', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        const providerType = result.current.getCrmProviderFromCode('salesforce-prod')

        expect(providerType).toBe('salesforce')
      })

      it('should return undefined for non-existent code', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        const providerType = result.current.getCrmProviderFromCode('non-existent-code')

        expect(providerType).toBeUndefined()
      })

      it('should return undefined for undefined code', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        const providerType = result.current.getCrmProviderFromCode(undefined)

        expect(providerType).toBeUndefined()
      })

      it('should return undefined for empty string code', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        const providerType = result.current.getCrmProviderFromCode('')

        expect(providerType).toBeUndefined()
      })

      it('should handle case sensitivity correctly', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        // Test with different case
        const upperCaseResult = result.current.getCrmProviderFromCode('HUBSPOT-MAIN')
        const lowerCaseResult = result.current.getCrmProviderFromCode('hubspot-main')

        expect(upperCaseResult).toBeUndefined()
        expect(lowerCaseResult).toBe('hubspot')
      })

      it('should find correct provider among multiple integrations', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        // Test all three integrations from default mock data
        expect(result.current.getCrmProviderFromCode('hubspot-main')).toBe('hubspot')
        expect(result.current.getCrmProviderFromCode('salesforce-prod')).toBe('salesforce')
        expect(result.current.getCrmProviderFromCode('hubspot-sandbox')).toBe('hubspot')
      })

      it('should return correct type when only one integration exists', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [
                {
                  __typename: 'SalesforceIntegration',
                  id: '1',
                  code: 'single-salesforce',
                  name: 'Single Salesforce',
                },
              ],
            },
          },
        })

        await act(() => wait(0))

        const providerType = result.current.getCrmProviderFromCode('single-salesforce')

        expect(providerType).toBe('salesforce')
      })

      it('should handle custom integration codes correctly', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [
                {
                  __typename: 'HubspotIntegration',
                  id: '1',
                  code: 'custom-hubspot-123',
                  name: 'Custom Hubspot',
                  defaultTargetedObject: 'COMPANIES',
                },
                {
                  __typename: 'SalesforceIntegration',
                  id: '2',
                  code: 'my-salesforce-integration',
                  name: 'My Salesforce Integration',
                },
              ],
            },
          },
        })

        await act(() => wait(0))

        expect(result.current.getCrmProviderFromCode('custom-hubspot-123')).toBe('hubspot')
        expect(result.current.getCrmProviderFromCode('my-salesforce-integration')).toBe(
          'salesforce',
        )
        expect(result.current.getCrmProviderFromCode('wrong-code')).toBeUndefined()
      })

      it('should work with Hubspot integrations having different defaultTargetedObject values', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [
                {
                  __typename: 'HubspotIntegration',
                  id: '1',
                  code: 'hubspot-companies',
                  name: 'Hubspot for Companies',
                  defaultTargetedObject: 'COMPANIES',
                },
                {
                  __typename: 'HubspotIntegration',
                  id: '2',
                  code: 'hubspot-contacts',
                  name: 'Hubspot for Contacts',
                  defaultTargetedObject: 'CONTACTS',
                },
              ],
            },
          },
        })

        await act(() => wait(0))

        expect(result.current.getCrmProviderFromCode('hubspot-companies')).toBe('hubspot')
        expect(result.current.getCrmProviderFromCode('hubspot-contacts')).toBe('hubspot')
      })
    })

    describe('when data is not loaded', () => {
      it('should return undefined when data is still loading', async () => {
        const { result } = await prepare()

        // Before data is loaded
        const providerType = result.current.getCrmProviderFromCode('hubspot-main')

        expect(providerType).toBeUndefined()
      })

      it('should return undefined when query failed', async () => {
        const { result } = await prepare({ error: true })

        await act(() => wait(0))

        const providerType = result.current.getCrmProviderFromCode('hubspot-main')

        expect(providerType).toBeUndefined()
      })

      it('should return undefined when integrations collection is empty', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [],
            },
          },
        })

        await act(() => wait(0))

        const providerType = result.current.getCrmProviderFromCode('any-code')

        expect(providerType).toBeUndefined()
      })

      it('should return undefined when integrations is null', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: null,
          },
        })

        await act(() => wait(0))

        const providerType = result.current.getCrmProviderFromCode('any-code')

        expect(providerType).toBeUndefined()
      })
    })

    describe('edge cases', () => {
      it('should handle integration without __typename', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [
                {
                  id: '1',
                  code: 'no-typename',
                  name: 'No Typename Integration',
                },
              ],
            },
          },
        })

        await act(() => wait(0))

        const providerType = result.current.getCrmProviderFromCode('no-typename')

        expect(providerType).toBeUndefined()
      })

      it('should handle integration without code property', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [
                {
                  __typename: 'HubspotIntegration',
                  id: '1',
                  name: 'No Code Integration',
                  defaultTargetedObject: 'COMPANIES',
                },
              ],
            },
          },
        })

        await act(() => wait(0))

        const providerType = result.current.getCrmProviderFromCode('any-code')

        expect(providerType).toBeUndefined()
      })

      it('should handle whitespace in codes', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [
                {
                  __typename: 'HubspotIntegration',
                  id: '1',
                  code: ' hubspot-with-spaces ',
                  name: 'Hubspot with Spaces',
                  defaultTargetedObject: 'COMPANIES',
                },
              ],
            },
          },
        })

        await act(() => wait(0))

        // Exact match should work
        expect(result.current.getCrmProviderFromCode(' hubspot-with-spaces ')).toBe('hubspot')

        // Trimmed version should not match (demonstrates exact matching)
        expect(result.current.getCrmProviderFromCode('hubspot-with-spaces')).toBeUndefined()
      })

      it('should handle Hubspot integration without defaultTargetedObject', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [
                {
                  __typename: 'HubspotIntegration',
                  id: '1',
                  code: 'hubspot-no-target',
                  name: 'Hubspot No Target',
                },
              ],
            },
          },
        })

        await act(() => wait(0))

        const providerType = result.current.getCrmProviderFromCode('hubspot-no-target')

        expect(providerType).toBe('hubspot')
      })
    })
  })
})
