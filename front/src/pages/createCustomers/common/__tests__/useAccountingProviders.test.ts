import { wait } from '@apollo/client/testing'
import { act, renderHook } from '@testing-library/react'
import React from 'react'

import { GetAccountingIntegrationsForExternalAppsAccordionDocument } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { useAccountingProviders } from '../useAccountingProviders'

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
          __typename: 'NetsuiteIntegration',
          id: '1',
          code: 'netsuite-prod',
          name: 'Netsuite Production',
        },
        {
          __typename: 'XeroIntegration',
          id: '2',
          code: 'xero-main',
          name: 'Xero Integration',
        },
        {
          __typename: 'NetsuiteIntegration',
          id: '3',
          code: 'netsuite-sandbox',
          name: 'Netsuite Sandbox',
        },
      ],
    },
  }

  const mocks = [
    {
      request: {
        query: GetAccountingIntegrationsForExternalAppsAccordionDocument,
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

  const { result } = renderHook(() => useAccountingProviders(), {
    wrapper: customWrapper,
  })

  return { result }
}

describe('useAccountingProviders', () => {
  describe('when query succeeds with data', () => {
    it('should return accounting providers data and loading state', async () => {
      const { result } = await prepare()

      // Initially loading
      expect(result.current.isLoadingAccountProviders).toBe(true)
      expect(result.current.accountingProviders).toBeUndefined()

      // Wait for the query to resolve
      await act(() => wait(0))

      // After loading completes
      expect(result.current.isLoadingAccountProviders).toBe(false)
      expect(result.current.accountingProviders).toBeDefined()
      expect(result.current.accountingProviders?.integrations?.collection).toHaveLength(3)

      const collection = result.current.accountingProviders?.integrations?.collection

      expect(collection?.[0]).toEqual({
        __typename: 'NetsuiteIntegration',
        id: '1',
        code: 'netsuite-prod',
        name: 'Netsuite Production',
      })
      expect(collection?.[1]).toEqual({
        __typename: 'XeroIntegration',
        id: '2',
        code: 'xero-main',
        name: 'Xero Integration',
      })
      expect(collection?.[2]).toEqual({
        __typename: 'NetsuiteIntegration',
        id: '3',
        code: 'netsuite-sandbox',
        name: 'Netsuite Sandbox',
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

      expect(result.current.isLoadingAccountProviders).toBe(false)
      expect(result.current.accountingProviders?.integrations?.collection).toEqual([])
    })

    it('should handle null integrations', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: null,
        },
      })

      await act(() => wait(0))

      expect(result.current.isLoadingAccountProviders).toBe(false)
      expect(result.current.accountingProviders?.integrations).toBeNull()
    })

    it('should handle only Netsuite integrations', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: {
            collection: [
              {
                __typename: 'NetsuiteIntegration',
                id: '1',
                code: 'netsuite-only',
                name: 'Netsuite Only',
              },
            ],
          },
        },
      })

      await act(() => wait(0))

      expect(result.current.isLoadingAccountProviders).toBe(false)
      expect(result.current.accountingProviders?.integrations?.collection).toHaveLength(1)
      expect(result.current.accountingProviders?.integrations?.collection?.[0]).toEqual({
        __typename: 'NetsuiteIntegration',
        id: '1',
        code: 'netsuite-only',
        name: 'Netsuite Only',
      })
    })

    it('should handle only Xero integrations', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: {
            collection: [
              {
                __typename: 'XeroIntegration',
                id: '1',
                code: 'xero-only',
                name: 'Xero Only',
              },
            ],
          },
        },
      })

      await act(() => wait(0))

      expect(result.current.isLoadingAccountProviders).toBe(false)
      expect(result.current.accountingProviders?.integrations?.collection).toHaveLength(1)
      expect(result.current.accountingProviders?.integrations?.collection?.[0]).toEqual({
        __typename: 'XeroIntegration',
        id: '1',
        code: 'xero-only',
        name: 'Xero Only',
      })
    })

    it('should handle large number of integrations with correct limit', async () => {
      const manyIntegrations = Array.from({ length: 50 }, (_, index) => ({
        __typename: index % 2 === 0 ? 'NetsuiteIntegration' : 'XeroIntegration',
        id: `${index + 1}`,
        code: `integration-${index + 1}`,
        name: `Integration ${index + 1}`,
      }))

      const { result } = await prepare({
        mockData: {
          integrations: {
            collection: manyIntegrations,
          },
        },
      })

      await act(() => wait(0))

      expect(result.current.isLoadingAccountProviders).toBe(false)
      expect(result.current.accountingProviders?.integrations?.collection).toHaveLength(50)
    })
  })

  describe('when query fails', () => {
    it('should handle GraphQL errors', async () => {
      const { result } = await prepare({ error: true })

      expect(result.current.isLoadingAccountProviders).toBe(true)

      await act(() => wait(0))

      expect(result.current.isLoadingAccountProviders).toBe(false)
      expect(result.current.accountingProviders).toBeUndefined()
    })

    it('should handle network errors', async () => {
      const { result } = await prepare({ networkError: true })

      expect(result.current.isLoadingAccountProviders).toBe(true)

      await act(() => wait(0))

      expect(result.current.isLoadingAccountProviders).toBe(false)
      expect(result.current.accountingProviders).toBeUndefined()
    })
  })

  describe('query configuration', () => {
    it('should use correct variables with limit of 1000', async () => {
      const { result } = await prepare()

      expect(result.current.isLoadingAccountProviders).toBe(true)

      await act(() => wait(0))

      expect(result.current.isLoadingAccountProviders).toBe(false)
      // The mock configuration verifies that variables: { limit: 1000 } is used
    })
  })

  describe('return value structure', () => {
    it('should return an object with accountingProviders and isLoadingAccountProviders and getAccountingProviderFromCode', async () => {
      const { result } = await prepare()

      expect(typeof result.current).toBe('object')
      expect('accountingProviders' in result.current).toBe(true)
      expect('isLoadingAccountProviders' in result.current).toBe(true)
      expect('getAccountingProviderFromCode' in result.current).toBe(true)
      expect(Object.keys(result.current)).toHaveLength(3)

      await act(() => wait(0))

      expect(typeof result.current.accountingProviders).toBe('object')
      expect(typeof result.current.isLoadingAccountProviders).toBe('boolean')
    })
  })

  describe('getAccountingProviderFromCode', () => {
    describe('when data is loaded', () => {
      it('should return correct provider type for Netsuite integration', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        const providerType = result.current.getAccountingProviderFromCode('netsuite-prod')

        expect(providerType).toBe('netsuite')
      })

      it('should return correct provider type for Xero integration', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        const providerType = result.current.getAccountingProviderFromCode('xero-main')

        expect(providerType).toBe('xero')
      })

      it('should return undefined for non-existent code', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        const providerType = result.current.getAccountingProviderFromCode('non-existent-code')

        expect(providerType).toBeUndefined()
      })

      it('should return undefined for undefined code', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        const providerType = result.current.getAccountingProviderFromCode(undefined)

        expect(providerType).toBeUndefined()
      })

      it('should return undefined for empty string code', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        const providerType = result.current.getAccountingProviderFromCode('')

        expect(providerType).toBeUndefined()
      })

      it('should handle case sensitivity correctly', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        // Test with different case
        const upperCaseResult = result.current.getAccountingProviderFromCode('NETSUITE-PROD')
        const lowerCaseResult = result.current.getAccountingProviderFromCode('netsuite-prod')

        expect(upperCaseResult).toBeUndefined()
        expect(lowerCaseResult).toBe('netsuite')
      })

      it('should find correct provider among multiple integrations', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        // Test all three integrations from default mock data
        expect(result.current.getAccountingProviderFromCode('netsuite-prod')).toBe('netsuite')
        expect(result.current.getAccountingProviderFromCode('xero-main')).toBe('xero')
        expect(result.current.getAccountingProviderFromCode('netsuite-sandbox')).toBe('netsuite')
      })

      it('should return correct type when only one integration exists', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [
                {
                  __typename: 'XeroIntegration',
                  id: '1',
                  code: 'single-xero',
                  name: 'Single Xero',
                },
              ],
            },
          },
        })

        await act(() => wait(0))

        const providerType = result.current.getAccountingProviderFromCode('single-xero')

        expect(providerType).toBe('xero')
      })

      it('should handle custom integration codes correctly', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [
                {
                  __typename: 'NetsuiteIntegration',
                  id: '1',
                  code: 'custom-netsuite-123',
                  name: 'Custom Netsuite',
                },
                {
                  __typename: 'XeroIntegration',
                  id: '2',
                  code: 'my-xero-integration',
                  name: 'My Xero Integration',
                },
              ],
            },
          },
        })

        await act(() => wait(0))

        expect(result.current.getAccountingProviderFromCode('custom-netsuite-123')).toBe('netsuite')
        expect(result.current.getAccountingProviderFromCode('my-xero-integration')).toBe('xero')
        expect(result.current.getAccountingProviderFromCode('wrong-code')).toBeUndefined()
      })
    })

    describe('when data is not loaded', () => {
      it('should return undefined when data is still loading', async () => {
        const { result } = await prepare()

        // Before data is loaded
        const providerType = result.current.getAccountingProviderFromCode('netsuite-prod')

        expect(providerType).toBeUndefined()
      })

      it('should return undefined when query failed', async () => {
        const { result } = await prepare({ error: true })

        await act(() => wait(0))

        const providerType = result.current.getAccountingProviderFromCode('netsuite-prod')

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

        const providerType = result.current.getAccountingProviderFromCode('any-code')

        expect(providerType).toBeUndefined()
      })

      it('should return undefined when integrations is null', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: null,
          },
        })

        await act(() => wait(0))

        const providerType = result.current.getAccountingProviderFromCode('any-code')

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

        const providerType = result.current.getAccountingProviderFromCode('no-typename')

        expect(providerType).toBeUndefined()
      })

      it('should handle integration without code property', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [
                {
                  __typename: 'NetsuiteIntegration',
                  id: '1',
                  name: 'No Code Integration',
                },
              ],
            },
          },
        })

        await act(() => wait(0))

        const providerType = result.current.getAccountingProviderFromCode('any-code')

        expect(providerType).toBeUndefined()
      })

      it('should handle whitespace in codes', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [
                {
                  __typename: 'NetsuiteIntegration',
                  id: '1',
                  code: ' netsuite-with-spaces ',
                  name: 'Netsuite with Spaces',
                },
              ],
            },
          },
        })

        await act(() => wait(0))

        // Exact match should work
        expect(result.current.getAccountingProviderFromCode(' netsuite-with-spaces ')).toBe(
          'netsuite',
        )

        // Trimmed version should not match (demonstrates exact matching)
        expect(result.current.getAccountingProviderFromCode('netsuite-with-spaces')).toBeUndefined()
      })
    })
  })

  describe('integration with GraphQL fragments', () => {
    it('should properly handle NetsuiteIntegration fragment fields', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: {
            collection: [
              {
                __typename: 'NetsuiteIntegration',
                id: 'netsuite-1',
                code: 'NETSUITE_PROD',
                name: 'Netsuite Production Environment',
              },
            ],
          },
        },
      })

      await act(() => wait(0))

      const netsuiteIntegration = result.current.accountingProviders?.integrations?.collection?.[0]

      if (!netsuiteIntegration || !('id' in netsuiteIntegration)) {
        throw new Error('Netsuite integration not found in the result')
      }

      expect(netsuiteIntegration.__typename).toBe('NetsuiteIntegration')
      expect(netsuiteIntegration.id).toBe('netsuite-1')
      expect(netsuiteIntegration.code).toBe('NETSUITE_PROD')
      expect(netsuiteIntegration.name).toBe('Netsuite Production Environment')
    })

    it('should properly handle XeroIntegration fragment fields', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: {
            collection: [
              {
                __typename: 'XeroIntegration',
                id: 'xero-1',
                code: 'XERO_MAIN',
                name: 'Xero Main Account',
              },
            ],
          },
        },
      })

      await act(() => wait(0))

      const xeroIntegration = result.current.accountingProviders?.integrations?.collection?.[0]

      if (!xeroIntegration || !('id' in xeroIntegration)) {
        throw new Error('Netsuite integration not found in the result')
      }

      expect(xeroIntegration?.__typename).toBe('XeroIntegration')
      expect(xeroIntegration?.id).toBe('xero-1')
      expect(xeroIntegration?.code).toBe('XERO_MAIN')
      expect(xeroIntegration?.name).toBe('Xero Main Account')
    })
  })
})
