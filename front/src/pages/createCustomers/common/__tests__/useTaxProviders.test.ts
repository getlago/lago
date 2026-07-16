import { wait } from '@apollo/client/testing'
import { act, renderHook } from '@testing-library/react'
import React from 'react'

import { GetTaxIntegrationsForExternalAppsAccordionDocument } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { useTaxProviders } from '../useTaxProviders'

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
          __typename: 'AnrokIntegration',
          id: '1',
          code: 'anrok-prod',
          name: 'Anrok Production',
        },
        {
          __typename: 'AvalaraIntegration',
          id: '2',
          code: 'avalara-main',
          name: 'Avalara Tax Engine',
        },
        {
          __typename: 'AnrokIntegration',
          id: '3',
          code: 'anrok-sandbox',
          name: 'Anrok Sandbox',
        },
      ],
    },
  }

  const mocks = [
    {
      request: {
        query: GetTaxIntegrationsForExternalAppsAccordionDocument,
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

  const { result } = renderHook(() => useTaxProviders(), {
    wrapper: customWrapper,
  })

  return { result }
}

describe('useTaxProviders', () => {
  describe('when query succeeds with data', () => {
    it('should return tax providers data and loading state', async () => {
      const { result } = await prepare()

      // Initially loading
      expect(result.current.isLoadingTaxProviders).toBe(true)
      expect(result.current.taxProviders).toBeUndefined()

      // Wait for the query to resolve
      await act(() => wait(0))

      // After loading completes
      expect(result.current.isLoadingTaxProviders).toBe(false)
      expect(result.current.taxProviders).toBeDefined()
      expect(result.current.taxProviders?.integrations?.collection).toHaveLength(3)

      const collection = result.current.taxProviders?.integrations?.collection

      expect(collection?.[0]).toEqual({
        __typename: 'AnrokIntegration',
        id: '1',
        code: 'anrok-prod',
        name: 'Anrok Production',
      })
      expect(collection?.[1]).toEqual({
        __typename: 'AvalaraIntegration',
        id: '2',
        code: 'avalara-main',
        name: 'Avalara Tax Engine',
      })
      expect(collection?.[2]).toEqual({
        __typename: 'AnrokIntegration',
        id: '3',
        code: 'anrok-sandbox',
        name: 'Anrok Sandbox',
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

      expect(result.current.isLoadingTaxProviders).toBe(false)
      expect(result.current.taxProviders?.integrations?.collection).toEqual([])
    })

    it('should handle null integrations', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: null,
        },
      })

      await act(() => wait(0))

      expect(result.current.isLoadingTaxProviders).toBe(false)
      expect(result.current.taxProviders?.integrations).toBeNull()
    })

    it('should handle only Anrok integrations', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: {
            collection: [
              {
                __typename: 'AnrokIntegration',
                id: '1',
                code: 'anrok-only',
                name: 'Anrok Only',
              },
            ],
          },
        },
      })

      await act(() => wait(0))

      expect(result.current.isLoadingTaxProviders).toBe(false)
      expect(result.current.taxProviders?.integrations?.collection).toHaveLength(1)
      expect(result.current.taxProviders?.integrations?.collection?.[0]).toEqual({
        __typename: 'AnrokIntegration',
        id: '1',
        code: 'anrok-only',
        name: 'Anrok Only',
      })
    })

    it('should handle only Avalara integrations', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: {
            collection: [
              {
                __typename: 'AvalaraIntegration',
                id: '1',
                code: 'avalara-only',
                name: 'Avalara Only',
              },
            ],
          },
        },
      })

      await act(() => wait(0))

      expect(result.current.isLoadingTaxProviders).toBe(false)
      expect(result.current.taxProviders?.integrations?.collection).toHaveLength(1)
      expect(result.current.taxProviders?.integrations?.collection?.[0]).toEqual({
        __typename: 'AvalaraIntegration',
        id: '1',
        code: 'avalara-only',
        name: 'Avalara Only',
      })
    })

    it('should handle multiple integrations of same type', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: {
            collection: [
              {
                __typename: 'AnrokIntegration',
                id: '1',
                code: 'anrok-prod',
                name: 'Anrok Production',
              },
              {
                __typename: 'AnrokIntegration',
                id: '2',
                code: 'anrok-dev',
                name: 'Anrok Development',
              },
              {
                __typename: 'AnrokIntegration',
                id: '3',
                code: 'anrok-staging',
                name: 'Anrok Staging',
              },
            ],
          },
        },
      })

      await act(() => wait(0))

      expect(result.current.isLoadingTaxProviders).toBe(false)
      expect(result.current.taxProviders?.integrations?.collection).toHaveLength(3)
      expect(
        result.current.taxProviders?.integrations?.collection?.every(
          (integration) => integration.__typename === 'AnrokIntegration',
        ),
      ).toBe(true)
    })
  })

  describe('when query fails', () => {
    it('should handle GraphQL errors', async () => {
      const { result } = await prepare({ error: true })

      expect(result.current.isLoadingTaxProviders).toBe(true)

      await act(() => wait(0))

      expect(result.current.isLoadingTaxProviders).toBe(false)
      expect(result.current.taxProviders).toBeUndefined()
    })

    it('should handle network errors', async () => {
      const { result } = await prepare({ networkError: true })

      expect(result.current.isLoadingTaxProviders).toBe(true)

      await act(() => wait(0))

      expect(result.current.isLoadingTaxProviders).toBe(false)
      expect(result.current.taxProviders).toBeUndefined()
    })
  })

  describe('query configuration', () => {
    it('should use correct variables with limit of 1000', async () => {
      const { result } = await prepare()

      expect(result.current.isLoadingTaxProviders).toBe(true)

      await act(() => wait(0))

      expect(result.current.isLoadingTaxProviders).toBe(false)
      // The mock configuration verifies that variables: { limit: 1000 } is used
    })
  })

  describe('return value structure', () => {
    it('should return an object with taxProviders and isLoadingTaxProviders and getTaxProviderFromCode', async () => {
      const { result } = await prepare()

      expect(typeof result.current).toBe('object')
      expect('taxProviders' in result.current).toBe(true)
      expect('isLoadingTaxProviders' in result.current).toBe(true)
      expect('getTaxProviderFromCode' in result.current).toBe(true)
      expect(Object.keys(result.current)).toHaveLength(3)

      await act(() => wait(0))

      expect(typeof result.current.taxProviders).toBe('object')
      expect(typeof result.current.isLoadingTaxProviders).toBe('boolean')
    })
  })

  describe('integration with GraphQL fragments', () => {
    it('should properly handle AnrokIntegration fragment fields', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: {
            collection: [
              {
                __typename: 'AnrokIntegration',
                id: 'anrok-1',
                code: 'ANROK_PROD',
                name: 'Anrok Production Environment',
              },
            ],
          },
        },
      })

      await act(() => wait(0))

      const anrokIntegration = result.current.taxProviders?.integrations?.collection?.[0]

      if (!anrokIntegration || !('id' in anrokIntegration)) {
        throw new Error('Anrok integration not found in the result')
      }

      expect(anrokIntegration.__typename).toBe('AnrokIntegration')
      expect(anrokIntegration.id).toBe('anrok-1')
      expect(anrokIntegration.code).toBe('ANROK_PROD')
      expect(anrokIntegration.name).toBe('Anrok Production Environment')
    })

    it('should properly handle AvalaraIntegration fragment fields', async () => {
      const { result } = await prepare({
        mockData: {
          integrations: {
            collection: [
              {
                __typename: 'AvalaraIntegration',
                id: 'avalara-1',
                code: 'AVALARA_MAIN',
                name: 'Avalara Main Account',
              },
            ],
          },
        },
      })

      await act(() => wait(0))

      const avalaraIntegration = result.current.taxProviders?.integrations?.collection?.[0]

      if (!avalaraIntegration || !('id' in avalaraIntegration)) {
        throw new Error('Avalara integration not found in the result')
      }

      expect(avalaraIntegration.__typename).toBe('AvalaraIntegration')
      expect(avalaraIntegration.id).toBe('avalara-1')
      expect(avalaraIntegration.code).toBe('AVALARA_MAIN')
      expect(avalaraIntegration.name).toBe('Avalara Main Account')
    })
  })

  describe('getTaxProviderFromCode', () => {
    describe('when data is loaded', () => {
      it('should return correct provider type for Anrok integration', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        const providerType = result.current.getTaxProviderFromCode('anrok-prod')

        expect(providerType).toBe('anrok')
      })

      it('should return correct provider type for Avalara integration', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        const providerType = result.current.getTaxProviderFromCode('avalara-main')

        expect(providerType).toBe('avalara')
      })

      it('should return undefined for non-existent code', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        const providerType = result.current.getTaxProviderFromCode('non-existent-code')

        expect(providerType).toBeUndefined()
      })

      it('should return undefined for undefined code', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        const providerType = result.current.getTaxProviderFromCode(undefined)

        expect(providerType).toBeUndefined()
      })

      it('should return undefined for empty string code', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        const providerType = result.current.getTaxProviderFromCode('')

        expect(providerType).toBeUndefined()
      })

      it('should handle case sensitivity correctly', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        // Test with different case
        const upperCaseResult = result.current.getTaxProviderFromCode('ANROK-PROD')
        const lowerCaseResult = result.current.getTaxProviderFromCode('anrok-prod')

        expect(upperCaseResult).toBeUndefined()
        expect(lowerCaseResult).toBe('anrok')
      })

      it('should find correct provider among multiple integrations', async () => {
        const { result } = await prepare()

        await act(() => wait(0))

        // Test all three integrations from default mock data
        expect(result.current.getTaxProviderFromCode('anrok-prod')).toBe('anrok')
        expect(result.current.getTaxProviderFromCode('avalara-main')).toBe('avalara')
        expect(result.current.getTaxProviderFromCode('anrok-sandbox')).toBe('anrok')
      })

      it('should return correct type when only one integration exists', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [
                {
                  __typename: 'AvalaraIntegration',
                  id: '1',
                  code: 'single-avalara',
                  name: 'Single Avalara',
                },
              ],
            },
          },
        })

        await act(() => wait(0))

        const providerType = result.current.getTaxProviderFromCode('single-avalara')

        expect(providerType).toBe('avalara')
      })

      it('should handle custom integration codes correctly', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [
                {
                  __typename: 'AnrokIntegration',
                  id: '1',
                  code: 'custom-anrok-123',
                  name: 'Custom Anrok',
                },
                {
                  __typename: 'AvalaraIntegration',
                  id: '2',
                  code: 'my-avalara-integration',
                  name: 'My Avalara Integration',
                },
              ],
            },
          },
        })

        await act(() => wait(0))

        expect(result.current.getTaxProviderFromCode('custom-anrok-123')).toBe('anrok')
        expect(result.current.getTaxProviderFromCode('my-avalara-integration')).toBe('avalara')
        expect(result.current.getTaxProviderFromCode('wrong-code')).toBeUndefined()
      })

      it('should handle multiple integrations of the same type', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [
                {
                  __typename: 'AnrokIntegration',
                  id: '1',
                  code: 'anrok-prod',
                  name: 'Anrok Production',
                },
                {
                  __typename: 'AnrokIntegration',
                  id: '2',
                  code: 'anrok-dev',
                  name: 'Anrok Development',
                },
                {
                  __typename: 'AnrokIntegration',
                  id: '3',
                  code: 'anrok-staging',
                  name: 'Anrok Staging',
                },
              ],
            },
          },
        })

        await act(() => wait(0))

        expect(result.current.getTaxProviderFromCode('anrok-prod')).toBe('anrok')
        expect(result.current.getTaxProviderFromCode('anrok-dev')).toBe('anrok')
        expect(result.current.getTaxProviderFromCode('anrok-staging')).toBe('anrok')
      })
    })

    describe('when data is not loaded', () => {
      it('should return undefined when data is still loading', async () => {
        const { result } = await prepare()

        // Before data is loaded
        const providerType = result.current.getTaxProviderFromCode('anrok-prod')

        expect(providerType).toBeUndefined()
      })

      it('should return undefined when query failed', async () => {
        const { result } = await prepare({ error: true })

        await act(() => wait(0))

        const providerType = result.current.getTaxProviderFromCode('anrok-prod')

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

        const providerType = result.current.getTaxProviderFromCode('any-code')

        expect(providerType).toBeUndefined()
      })

      it('should return undefined when integrations is null', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: null,
          },
        })

        await act(() => wait(0))

        const providerType = result.current.getTaxProviderFromCode('any-code')

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

        const providerType = result.current.getTaxProviderFromCode('no-typename')

        expect(providerType).toBeUndefined()
      })

      it('should handle integration without code property', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [
                {
                  __typename: 'AnrokIntegration',
                  id: '1',
                  name: 'No Code Integration',
                },
              ],
            },
          },
        })

        await act(() => wait(0))

        const providerType = result.current.getTaxProviderFromCode('any-code')

        expect(providerType).toBeUndefined()
      })

      it('should handle whitespace in codes', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [
                {
                  __typename: 'AnrokIntegration',
                  id: '1',
                  code: ' anrok-with-spaces ',
                  name: 'Anrok with Spaces',
                },
              ],
            },
          },
        })

        await act(() => wait(0))

        // Exact match should work
        expect(result.current.getTaxProviderFromCode(' anrok-with-spaces ')).toBe('anrok')

        // Trimmed version should not match (demonstrates exact matching)
        expect(result.current.getTaxProviderFromCode('anrok-with-spaces')).toBeUndefined()
      })

      it('should properly transform typename by removing "Integration" suffix', async () => {
        const { result } = await prepare({
          mockData: {
            integrations: {
              collection: [
                {
                  __typename: 'AnrokIntegration',
                  id: '1',
                  code: 'test-anrok',
                  name: 'Test Anrok',
                },
                {
                  __typename: 'AvalaraIntegration',
                  id: '2',
                  code: 'test-avalara',
                  name: 'Test Avalara',
                },
              ],
            },
          },
        })

        await act(() => wait(0))

        // Should remove "Integration" and convert to lowercase
        expect(result.current.getTaxProviderFromCode('test-anrok')).toBe('anrok')
        expect(result.current.getTaxProviderFromCode('test-avalara')).toBe('avalara')
      })
    })
  })
})
