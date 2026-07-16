import { gql, InMemoryCache } from '@apollo/client'
import { MockedProvider } from '@apollo/client/testing'
import { act, renderHook, waitFor } from '@testing-library/react'
import React from 'react'

import {
  CreateXeroIntegrationMappingDocument,
  DeleteXeroIntegrationMappingDocument,
  GetXeroIntegrationItemsDocument,
  MappableTypeEnum,
  MappingTypeEnum,
  UpdateXeroIntegrationMappingDocument,
} from '~/generated/graphql'
import { AllTheProviders, TestMocksType } from '~/test-utils'

import { useXeroIntegrationMappingCRUD } from '../useXeroIntegrationMappingCRUD'

const INTEGRATION_ID = 'integration-123'
const MAPPABLE_ID = 'billable-metric-456'
const MAPPING_ID = 'mapping-789'

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const createWrapper = (mocks: TestMocksType) => {
  return ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({
      children,
      mocks,
      forceTypenames: true,
    })
}

/**
 * Wrapper that passes a custom InMemoryCache to MockedProvider so we can
 * assert against it after mutations run their `update` callbacks.
 */
const createCacheWrapper = (mocks: TestMocksType, cache: InMemoryCache) => {
  const Wrapper = ({ children }: { children: React.ReactNode }) => {
    return React.createElement(MockedProvider, { mocks, addTypename: true, cache }, children)
  }

  Wrapper.displayName = 'CacheWrapper'
  return Wrapper
}

const buildGetItemsMock = () => ({
  request: {
    query: GetXeroIntegrationItemsDocument,
    variables: {
      limit: 1000,
      integrationId: INTEGRATION_ID,
      itemType: 'standard',
    },
  },
  result: {
    data: {
      integrationItems: {
        __typename: 'IntegrationItemCollection',
        collection: [
          {
            __typename: 'IntegrationItem',
            id: 'item-1',
            externalId: 'ext-1',
            externalName: 'External Item',
            externalAccountCode: 'ACC001',
            itemType: 'standard',
          },
        ],
        metadata: {
          __typename: 'CollectionMetadata',
          currentPage: 1,
          totalPages: 1,
          totalCount: 1,
        },
      },
    },
  },
})

const buildCreateMappingMock = () => ({
  request: {
    query: CreateXeroIntegrationMappingDocument,
    variables: {
      input: {
        integrationId: INTEGRATION_ID,
        mappableId: MAPPABLE_ID,
        mappableType: MappableTypeEnum.BillableMetric,
        externalId: 'ext-1',
        externalName: 'External Item',
        externalAccountCode: 'ACC001',
      },
    },
  },
  result: {
    data: {
      createIntegrationMapping: {
        __typename: 'Mapping',
        id: MAPPING_ID,
        externalId: 'ext-1',
        externalName: 'External Item',
        externalAccountCode: 'ACC001',
      },
    },
  },
})

const buildUpdateMappingMock = () => ({
  request: {
    query: UpdateXeroIntegrationMappingDocument,
    variables: {
      input: {
        id: MAPPING_ID,
        integrationId: INTEGRATION_ID,
        mappableType: MappableTypeEnum.BillableMetric,
        mappableId: MAPPABLE_ID,
        externalId: 'ext-2',
        externalName: 'Updated Item',
        externalAccountCode: 'ACC002',
      },
    },
  },
  result: {
    data: {
      updateIntegrationMapping: {
        __typename: 'Mapping',
        id: MAPPING_ID,
      },
    },
  },
})

const buildDeleteMappingMock = () => ({
  request: {
    query: DeleteXeroIntegrationMappingDocument,
    variables: {
      input: { id: MAPPING_ID },
    },
  },
  result: {
    data: {
      destroyIntegrationMapping: {
        __typename: 'DestroyIntegrationMappingPayload',
        id: MAPPING_ID,
      },
    },
  },
})

const SIMPLE_MAPPING_FRAGMENT = gql`
  fragment TestMappingRead on Mapping {
    id
    externalId
    externalName
    externalAccountCode
  }
`

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('useXeroIntegrationMappingCRUD', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  // -------------------------------------------------------------------------
  // Hook API shape
  // -------------------------------------------------------------------------
  describe('hook return value', () => {
    it('returns all expected functions and state', () => {
      const { result } = renderHook(
        () => useXeroIntegrationMappingCRUD(MappableTypeEnum.BillableMetric, INTEGRATION_ID),
        { wrapper: createWrapper([]) },
      )

      expect(typeof result.current.getXeroIntegrationItems).toBe('function')
      expect(typeof result.current.createMapping).toBe('function')
      expect(typeof result.current.updateMapping).toBe('function')
      expect(typeof result.current.deleteMapping).toBe('function')
      expect(typeof result.current.createCollectionMapping).toBe('function')
      expect(typeof result.current.updateCollectionMapping).toBe('function')
      expect(typeof result.current.deleteCollectionMapping).toBe('function')
      expect(typeof result.current.triggerAccountItemRefetch).toBe('function')
      expect(typeof result.current.triggerItemRefetch).toBe('function')
      expect(result.current.initialItemFetchLoading).toBe(false)
      expect(result.current.initialItemFetchData).toBeUndefined()
      expect(result.current.accountItemsLoading).toBe(false)
      expect(result.current.itemsLoading).toBe(false)
    })
  })

  // -------------------------------------------------------------------------
  // getXeroIntegrationItems wrapper — guard against undefined integrationId
  // -------------------------------------------------------------------------
  describe('getXeroIntegrationItems wrapper', () => {
    it('does not execute the query when integrationId is undefined', async () => {
      const { result } = renderHook(
        () => useXeroIntegrationMappingCRUD(MappableTypeEnum.BillableMetric, undefined),
        { wrapper: createWrapper([buildGetItemsMock()]) },
      )

      // Call the wrapped function — should return undefined (no-op)
      let returnValue: unknown

      await act(async () => {
        returnValue = result.current.getXeroIntegrationItems()
      })

      expect(returnValue).toBeUndefined()
      expect(result.current.initialItemFetchData).toBeUndefined()
    })

    it('executes the query when integrationId is provided', async () => {
      const { result } = renderHook(
        () => useXeroIntegrationMappingCRUD(MappableTypeEnum.BillableMetric, INTEGRATION_ID),
        { wrapper: createWrapper([buildGetItemsMock()]) },
      )

      await act(async () => {
        await result.current.getXeroIntegrationItems()
      })

      await waitFor(() => {
        expect(result.current.initialItemFetchData?.integrationItems?.collection).toHaveLength(1)
      })
    })

    it('merges caller-provided variables (e.g. searchTerm) with injected variables', async () => {
      const searchMock = {
        request: {
          query: GetXeroIntegrationItemsDocument,
          variables: {
            limit: 1000,
            integrationId: INTEGRATION_ID,
            itemType: 'standard',
            searchTerm: 'test',
          },
        },
        result: {
          data: {
            integrationItems: {
              __typename: 'IntegrationItemCollection',
              collection: [],
              metadata: {
                __typename: 'CollectionMetadata',
                currentPage: 1,
                totalPages: 1,
                totalCount: 0,
              },
            },
          },
        },
      }

      const { result } = renderHook(
        () => useXeroIntegrationMappingCRUD(MappableTypeEnum.BillableMetric, INTEGRATION_ID),
        { wrapper: createWrapper([searchMock]) },
      )

      await act(async () => {
        await result.current.getXeroIntegrationItems({
          variables: {
            searchTerm: 'test',
            integrationId: '',
          },
        })
      })

      await waitFor(() => {
        expect(result.current.initialItemFetchData?.integrationItems?.collection).toHaveLength(0)
      })
    })

    it('reads the latest integrationId from the ref when called after rerender', async () => {
      // Start with undefined integrationId
      const { result, rerender } = renderHook(
        ({ id }: { id: string | undefined }) =>
          useXeroIntegrationMappingCRUD(MappableTypeEnum.BillableMetric, id),
        {
          initialProps: { id: undefined as string | undefined },
          wrapper: createWrapper([buildGetItemsMock()]),
        },
      )

      // Query should be a no-op when integrationId is undefined
      let returnValue: unknown

      await act(async () => {
        returnValue = result.current.getXeroIntegrationItems()
      })

      expect(returnValue).toBeUndefined()

      // Re-render with a valid integrationId
      rerender({ id: INTEGRATION_ID })

      // Now the same wrapper should use the updated integrationId from ref
      await act(async () => {
        await result.current.getXeroIntegrationItems()
      })

      await waitFor(() => {
        expect(result.current.initialItemFetchData?.integrationItems?.collection).toHaveLength(1)
      })
    })
  })

  // -------------------------------------------------------------------------
  // Cache update: createMapping for paginated types
  // -------------------------------------------------------------------------
  describe('createMapping cache update (paginated)', () => {
    it('writes the new Mapping entity to the cache', async () => {
      const cache = new InMemoryCache()

      // Seed a parent BillableMetric entity with empty integrationMappings
      cache.writeFragment({
        id: cache.identify({ __typename: 'BillableMetric', id: MAPPABLE_ID }),
        fragment: gql`
          fragment SeedBM on BillableMetric {
            id
            integrationMappings {
              id
            }
          }
        `,
        data: {
          __typename: 'BillableMetric',
          id: MAPPABLE_ID,
          integrationMappings: [],
        },
      })

      const { result } = renderHook(
        () => useXeroIntegrationMappingCRUD(MappableTypeEnum.BillableMetric, INTEGRATION_ID),
        { wrapper: createCacheWrapper([buildCreateMappingMock()], cache) },
      )

      await act(async () => {
        await result.current.createMapping({
          variables: {
            input: {
              integrationId: INTEGRATION_ID,
              mappableId: MAPPABLE_ID,
              mappableType: MappableTypeEnum.BillableMetric,
              externalId: 'ext-1',
              externalName: 'External Item',
              externalAccountCode: 'ACC001',
            },
          },
        })
      })

      // Verify the Mapping entity was written to the Apollo cache
      await waitFor(() => {
        const mappingData = cache.readFragment({
          id: cache.identify({ __typename: 'Mapping', id: MAPPING_ID }),
          fragment: SIMPLE_MAPPING_FRAGMENT,
        })

        expect(mappingData).toEqual(
          expect.objectContaining({
            id: MAPPING_ID,
            externalId: 'ext-1',
            externalName: 'External Item',
          }),
        )
      })
    })
  })

  // -------------------------------------------------------------------------
  // Cache update: updateMapping for paginated types
  // -------------------------------------------------------------------------
  describe('updateMapping cache update (paginated)', () => {
    it('updates the mapping entity fields directly in cache', async () => {
      const cache = new InMemoryCache()

      // Seed the cache with the existing Mapping entity
      cache.writeFragment({
        id: cache.identify({ __typename: 'Mapping', id: MAPPING_ID }),
        fragment: SIMPLE_MAPPING_FRAGMENT,
        data: {
          __typename: 'Mapping',
          id: MAPPING_ID,
          externalId: 'ext-1',
          externalName: 'Old Name',
          externalAccountCode: 'OLD001',
        },
      })

      const { result } = renderHook(
        () => useXeroIntegrationMappingCRUD(MappableTypeEnum.BillableMetric, INTEGRATION_ID),
        { wrapper: createCacheWrapper([buildUpdateMappingMock()], cache) },
      )

      await act(async () => {
        await result.current.updateMapping({
          variables: {
            input: {
              id: MAPPING_ID,
              integrationId: INTEGRATION_ID,
              mappableType: MappableTypeEnum.BillableMetric,
              mappableId: MAPPABLE_ID,
              externalId: 'ext-2',
              externalName: 'Updated Item',
              externalAccountCode: 'ACC002',
            },
          },
        })
      })

      await waitFor(() => {
        const updated = cache.readFragment({
          id: cache.identify({ __typename: 'Mapping', id: MAPPING_ID }),
          fragment: SIMPLE_MAPPING_FRAGMENT,
        })

        expect(updated).toEqual(
          expect.objectContaining({
            externalId: 'ext-2',
            externalName: 'Updated Item',
            externalAccountCode: 'ACC002',
          }),
        )
      })
    })
  })

  // -------------------------------------------------------------------------
  // Cache update: deleteMapping for paginated types
  // -------------------------------------------------------------------------
  describe('deleteMapping cache update (paginated)', () => {
    it('evicts the mapping entity from cache', async () => {
      const cache = new InMemoryCache()

      // Seed the Mapping entity with mappableId (needed for parent lookup)
      cache.writeFragment({
        id: cache.identify({ __typename: 'Mapping', id: MAPPING_ID }),
        fragment: gql`
          fragment SeedDeleteMapping on Mapping {
            id
            mappableId
            externalId
          }
        `,
        data: {
          __typename: 'Mapping',
          id: MAPPING_ID,
          mappableId: MAPPABLE_ID,
          externalId: 'ext-1',
        },
      })

      const { result } = renderHook(
        () => useXeroIntegrationMappingCRUD(MappableTypeEnum.BillableMetric, INTEGRATION_ID),
        { wrapper: createCacheWrapper([buildDeleteMappingMock()], cache) },
      )

      await act(async () => {
        await result.current.deleteMapping({
          variables: { input: { id: MAPPING_ID } },
        })
      })

      await waitFor(() => {
        // The Mapping entity should be evicted from cache
        const evicted = cache.readFragment({
          id: cache.identify({ __typename: 'Mapping', id: MAPPING_ID }),
          fragment: gql`
            fragment ReadEvicted on Mapping {
              id
            }
          `,
        })

        expect(evicted).toBeNull()
      })
    })
  })

  // -------------------------------------------------------------------------
  // Non-paginated types use refetchQueries instead of cache updates
  // -------------------------------------------------------------------------
  describe('non-paginated types (MappingTypeEnum)', () => {
    it('returns mutation functions without error', () => {
      const { result } = renderHook(
        () => useXeroIntegrationMappingCRUD(MappingTypeEnum.Coupon, INTEGRATION_ID),
        { wrapper: createWrapper([]) },
      )

      expect(typeof result.current.createMapping).toBe('function')
      expect(typeof result.current.updateMapping).toBe('function')
      expect(typeof result.current.deleteMapping).toBe('function')
    })
  })
})
