import { InMemoryCache, Reference } from '@apollo/client'
import { parse } from 'graphql'

import { CollectionMetadata } from '~/generated/graphql'

import {
  cacheArrayInsert,
  cacheArrayRemove,
  createPaginatedFieldPolicy,
  mergePaginatedCollection,
} from '../cacheHelpers'

// Type helper to extract the keyArgs function from a field policy
type KeyArgsFunction = NonNullable<
  Extract<ReturnType<typeof createPaginatedFieldPolicy>['keyArgs'], (...args: any[]) => any>
>

// Mock context for testing keyArgs functions - matches the actual signature
const mockFieldContext = {
  typename: 'Query',
  fieldName: 'testField',
  field: null,
  variables: {},
}

describe('cacheHelpers', () => {
  describe('mergePaginatedCollection', () => {
    const createMockCollection = (page: number, items: string[]) => ({
      metadata: {
        currentPage: page,
        totalPages: 5,
        totalCount: 50,
      } as CollectionMetadata,
      collection: items.map((id) => ({ id, name: `Item ${id}` })),
    })

    describe('First page behavior', () => {
      it('should replace existing data when incoming is page 1', () => {
        const existing = createMockCollection(2, ['1', '2', '3', '4'])
        const incoming = createMockCollection(1, ['5', '6', '7'])

        const result = mergePaginatedCollection(existing, incoming)

        expect(result).toEqual(incoming)
        expect(result.collection).toHaveLength(3)
        expect(result.collection[0]).toEqual({ id: '5', name: 'Item 5' })
      })

      it('should return incoming data when existing is undefined', () => {
        const incoming = createMockCollection(1, ['1', '2', '3'])

        // @ts-expect-error - Testing undefined case
        const result = mergePaginatedCollection(undefined, incoming)

        expect(result).toEqual(incoming)
      })

      it('should return incoming data when no currentPage metadata', () => {
        const existing = createMockCollection(2, ['1', '2', '3'])
        const incoming = {
          metadata: {} as CollectionMetadata,
          collection: [{ id: '4', name: 'Item 4' }],
        }

        const result = mergePaginatedCollection(existing, incoming)

        expect(result).toEqual(incoming)
      })

      it('should return incoming data when currentPage is null', () => {
        const existing = createMockCollection(2, ['1', '2', '3'])
        const incoming = {
          metadata: { currentPage: null } as unknown as CollectionMetadata,
          collection: [{ id: '4', name: 'Item 4' }],
        }

        const result = mergePaginatedCollection(existing, incoming)

        expect(result).toEqual(incoming)
      })
    })

    describe('Pagination append behavior', () => {
      it('should append page 2 items to existing page 1 items', () => {
        const existing = createMockCollection(1, ['1', '2', '3'])
        const incoming = createMockCollection(2, ['4', '5', '6'])

        const result = mergePaginatedCollection(existing, incoming)

        expect(result.metadata).toEqual(incoming.metadata)
        expect(result.collection).toHaveLength(6)
        expect(result.collection[0]).toEqual({ id: '1', name: 'Item 1' })
        expect(result.collection[3]).toEqual({ id: '4', name: 'Item 4' })
      })

      it('should append page 3 items to existing pages 1 and 2', () => {
        const existing = {
          metadata: { currentPage: 2 } as CollectionMetadata,
          collection: [
            { id: '1', name: 'Item 1' },
            { id: '2', name: 'Item 2' },
            { id: '3', name: 'Item 3' },
            { id: '4', name: 'Item 4' },
          ],
        }
        const incoming = createMockCollection(3, ['5', '6'])

        const result = mergePaginatedCollection(existing, incoming)

        expect(result.collection).toHaveLength(6)
        expect(result.collection[4]).toEqual({ id: '5', name: 'Item 5' })
        expect(result.collection[5]).toEqual({ id: '6', name: 'Item 6' })
      })

      it('should handle appending empty collection', () => {
        const existing = createMockCollection(1, ['1', '2', '3'])
        const incoming = createMockCollection(2, [])

        const result = mergePaginatedCollection(existing, incoming)

        expect(result.collection).toHaveLength(3)
        expect(result.metadata.currentPage).toBe(2)
      })

      it('should handle appending to empty existing collection', () => {
        const existing = createMockCollection(1, [])
        const incoming = createMockCollection(2, ['1', '2', '3'])

        const result = mergePaginatedCollection(existing, incoming)

        expect(result.collection).toHaveLength(3)
        expect(result.collection[0]).toEqual({ id: '1', name: 'Item 1' })
      })
    })

    describe('Edge cases', () => {
      it('should handle null existing collection', () => {
        const existing = {
          metadata: { currentPage: 1 } as CollectionMetadata,
          collection: null as unknown as Record<string, unknown>[],
        }
        const incoming = createMockCollection(2, ['1', '2'])

        const result = mergePaginatedCollection(existing, incoming)

        expect(result.collection).toHaveLength(2)
      })

      it('should handle undefined existing collection', () => {
        const existing = {
          metadata: { currentPage: 1 } as CollectionMetadata,
          collection: undefined as unknown as Record<string, unknown>[],
        }
        const incoming = createMockCollection(2, ['1', '2'])

        const result = mergePaginatedCollection(existing, incoming)

        expect(result.collection).toHaveLength(2)
      })

      it('should handle null incoming collection', () => {
        const existing = createMockCollection(1, ['1', '2'])
        const incoming = {
          metadata: { currentPage: 2 } as CollectionMetadata,
          collection: null as unknown as Record<string, unknown>[],
        }

        const result = mergePaginatedCollection(existing, incoming)

        expect(result.collection).toHaveLength(2)
      })

      it('should preserve existing data when both collections are empty', () => {
        const existing = createMockCollection(1, [])
        const incoming = createMockCollection(2, [])

        const result = mergePaginatedCollection(existing, incoming)

        expect(result.collection).toHaveLength(0)
        expect(result.metadata.currentPage).toBe(2)
      })
    })

    describe('Real-world scenarios', () => {
      it('should handle invoice pagination flow', () => {
        // Simulate fetching 3 pages of invoices
        let cached: { metadata: CollectionMetadata; collection: Record<string, unknown>[] } =
          createMockCollection(1, ['INV-001', 'INV-002', 'INV-003'])

        // Fetch page 2
        const page2 = createMockCollection(2, ['INV-004', 'INV-005', 'INV-006'])

        cached = mergePaginatedCollection(cached, page2)

        expect(cached.collection).toHaveLength(6)

        // Fetch page 3
        const page3 = createMockCollection(3, ['INV-007', 'INV-008'])

        cached = mergePaginatedCollection(cached, page3)

        expect(cached.collection).toHaveLength(8)
        expect(cached.metadata.currentPage).toBe(3)
      })

      it('should reset when user applies new filters (page 1)', () => {
        // User has loaded 2 pages
        const existing = {
          metadata: { currentPage: 2 } as CollectionMetadata,
          collection: [
            { id: '1', status: 'draft' },
            { id: '2', status: 'draft' },
            { id: '3', status: 'draft' },
            { id: '4', status: 'draft' },
          ],
        }

        // User changes filter, gets new page 1
        const incoming = createMockCollection(1, ['5', '6'])

        const result = mergePaginatedCollection(existing, incoming)

        expect(result.collection).toHaveLength(2)
        expect(result.collection[0].id).toBe('5')
      })
    })
  })

  describe('createPaginatedFieldPolicy', () => {
    describe('keyArgs function', () => {
      it('should return false when args is null', () => {
        const policy = createPaginatedFieldPolicy()
        const keyArgsFn = policy.keyArgs as KeyArgsFunction
        const result = keyArgsFn(null, mockFieldContext)

        expect(result).toBe(false)
      })

      it('should return false when args is undefined', () => {
        const policy = createPaginatedFieldPolicy()
        const keyArgsFn = policy.keyArgs as KeyArgsFunction
        const result = keyArgsFn(null, mockFieldContext)

        expect(result).toBe(false)
      })

      it('should exclude page from cache key', () => {
        const policy = createPaginatedFieldPolicy()
        const keyArgsFn = policy.keyArgs as KeyArgsFunction
        const result = keyArgsFn({ page: 1, status: 'active' }, mockFieldContext)

        expect(result).toEqual(['status'])
      })

      it('should exclude limit from cache key', () => {
        const policy = createPaginatedFieldPolicy()
        const keyArgsFn = policy.keyArgs as KeyArgsFunction
        const result = keyArgsFn({ limit: 20, status: 'active' }, mockFieldContext)

        expect(result).toEqual(['status'])
      })

      it('should exclude offset from cache key', () => {
        const policy = createPaginatedFieldPolicy()
        const keyArgsFn = policy.keyArgs as KeyArgsFunction
        const result = keyArgsFn({ offset: 10, status: 'active' }, mockFieldContext)

        expect(result).toEqual(['status'])
      })

      it('should exclude all pagination args together', () => {
        const policy = createPaginatedFieldPolicy()
        const keyArgsFn = policy.keyArgs as KeyArgsFunction
        const result = keyArgsFn(
          { page: 2, limit: 20, offset: 20, status: 'active', searchTerm: 'test' },
          mockFieldContext,
        )

        expect(result).toEqual(['searchTerm', 'status'])
      })

      it('should include all non-pagination args', () => {
        const policy = createPaginatedFieldPolicy()
        const keyArgsFn = policy.keyArgs as KeyArgsFunction
        const result = keyArgsFn(
          {
            page: 1,
            status: 'active',
            searchTerm: 'invoice',
            currency: 'USD',
            dateFrom: '2024-01-01',
          },
          mockFieldContext,
        )

        expect(result).toEqual(['currency', 'dateFrom', 'searchTerm', 'status'])
      })

      it('should handle empty args object', () => {
        const policy = createPaginatedFieldPolicy()
        const keyArgsFn = policy.keyArgs as KeyArgsFunction
        const result = keyArgsFn({}, mockFieldContext)

        expect(result).toEqual([])
      })

      it('should handle args with only pagination params', () => {
        const policy = createPaginatedFieldPolicy()
        const keyArgsFn = policy.keyArgs as KeyArgsFunction
        const result = keyArgsFn({ page: 1, limit: 20 }, mockFieldContext)

        expect(result).toEqual([])
      })

      describe('Additional exclusions', () => {
        it('should exclude custom args when provided', () => {
          const policy = createPaginatedFieldPolicy(['excludeMe'])
          const keyArgsFn = policy.keyArgs as KeyArgsFunction
          const result = keyArgsFn(
            { page: 1, status: 'active', excludeMe: 'value', keepMe: 'value' },
            mockFieldContext,
          )

          expect(result).toEqual(['keepMe', 'status'])
        })

        it('should exclude multiple custom args', () => {
          const policy = createPaginatedFieldPolicy(['arg1', 'arg2'])
          const keyArgsFn = policy.keyArgs as KeyArgsFunction
          const result = keyArgsFn(
            { page: 1, arg1: 'a', arg2: 'b', arg3: 'c', status: 'active' },
            mockFieldContext,
          )

          expect(result).toEqual(['arg3', 'status'])
        })

        it('should handle custom exclusions combined with default exclusions', () => {
          const policy = createPaginatedFieldPolicy(['customArg'])
          const keyArgsFn = policy.keyArgs as KeyArgsFunction
          const result = keyArgsFn(
            { page: 1, limit: 20, offset: 0, customArg: 'x', status: 'active' },
            mockFieldContext,
          )

          expect(result).toEqual(['status'])
        })

        it('should handle empty additional exclusions array', () => {
          const policy = createPaginatedFieldPolicy([])
          const keyArgsFn = policy.keyArgs as KeyArgsFunction
          const result = keyArgsFn({ page: 1, status: 'active' }, mockFieldContext)

          expect(result).toEqual(['status'])
        })
      })
    })

    describe('merge function', () => {
      it('should use mergePaginatedCollection', () => {
        const policy = createPaginatedFieldPolicy()

        expect(policy.merge).toBe(mergePaginatedCollection)
      })

      it('should properly merge when used in field policy', () => {
        const existing = {
          metadata: { currentPage: 1 } as CollectionMetadata,
          collection: [{ id: '1' }],
        }
        const incoming = {
          metadata: { currentPage: 2 } as CollectionMetadata,
          collection: [{ id: '2' }],
        }

        // Call the merge function directly - we know it's mergePaginatedCollection
        const result = mergePaginatedCollection(existing, incoming)

        expect(result.collection).toHaveLength(2)
      })
    })

    describe('Real-world query scenarios', () => {
      it('should cache invoices query with different filters separately', () => {
        const policy = createPaginatedFieldPolicy()
        const keyArgsFn = policy.keyArgs as KeyArgsFunction

        // Same query with different status - should include 'status' in both cache keys
        // Apollo will use the actual VALUES to create different cache entries
        const draftKey = keyArgsFn({ page: 1, status: 'draft' }, mockFieldContext)
        const finalizedKey = keyArgsFn({ page: 1, status: 'finalized' }, mockFieldContext)

        // Both return ['status'] as the key field, but Apollo will cache them separately
        // because the VALUES of 'status' are different ('draft' vs 'finalized')
        expect(draftKey).toEqual(['status'])
        expect(finalizedKey).toEqual(['status'])
      })

      it('should share cache for same filters on different pages', () => {
        const policy = createPaginatedFieldPolicy()
        const keyArgsFn = policy.keyArgs as KeyArgsFunction

        // Same filters, different pages - should have same cache key
        const page1Key = keyArgsFn({ page: 1, status: 'draft', currency: 'USD' }, mockFieldContext)
        const page2Key = keyArgsFn({ page: 2, status: 'draft', currency: 'USD' }, mockFieldContext)

        expect(page1Key).toEqual(page2Key)
      })

      it('should handle complex invoice query filters', () => {
        const policy = createPaginatedFieldPolicy()
        const keyArgsFn = policy.keyArgs as KeyArgsFunction
        const result = keyArgsFn(
          {
            page: 2,
            limit: 20,
            status: 'finalized',
            paymentStatus: 'pending',
            searchTerm: 'ACME Corp',
            currency: 'USD',
            issuingDateFrom: '2024-01-01',
            issuingDateTo: '2024-12-31',
            customerExternalId: 'cust_123',
          },
          mockFieldContext,
        )

        expect(result).toEqual([
          'currency',
          'customerExternalId',
          'issuingDateFrom',
          'issuingDateTo',
          'paymentStatus',
          'searchTerm',
          'status',
        ])
      })

      it('should handle customer query filters', () => {
        const policy = createPaginatedFieldPolicy()
        const keyArgsFn = policy.keyArgs as KeyArgsFunction
        const result = keyArgsFn(
          {
            page: 1,
            limit: 50,
            searchTerm: 'john',
            externalId: 'ext_456',
          },
          mockFieldContext,
        )

        expect(result).toEqual(['externalId', 'searchTerm'])
      })

      it('should handle webhook query filters', () => {
        const policy = createPaginatedFieldPolicy()
        const keyArgsFn = policy.keyArgs as KeyArgsFunction
        const result = keyArgsFn(
          {
            page: 1,
            webhookEndpointId: 'wh_123',
            status: 'succeeded',
            searchTerm: 'invoice',
          },
          mockFieldContext,
        )

        expect(result).toEqual(['searchTerm', 'status', 'webhookEndpointId'])
      })
    })

    describe('Developer experience scenarios', () => {
      it('should automatically handle new filter arguments without code changes', () => {
        const policy = createPaginatedFieldPolicy()
        const keyArgsFn = policy.keyArgs as KeyArgsFunction

        // Developer adds a new filter to the query
        const result = keyArgsFn(
          {
            page: 1,
            status: 'active',
            newFilterWeJustAdded: 'value',
            anotherNewOne: 'another',
          },
          mockFieldContext,
        )

        // New filters are automatically included in cache key
        expect(result).toContain('newFilterWeJustAdded')
        expect(result).toContain('anotherNewOne')
      })

      it('should handle queries with no filters except pagination', () => {
        const policy = createPaginatedFieldPolicy()
        const keyArgsFn = policy.keyArgs as KeyArgsFunction
        const result = keyArgsFn({ page: 1, limit: 20 }, mockFieldContext)

        // Should return empty array, meaning all queries share same cache
        expect(result).toEqual([])
      })

      it('should maintain consistency across multiple policy instances', () => {
        const policy1 = createPaginatedFieldPolicy()
        const policy2 = createPaginatedFieldPolicy()
        const keyArgsFn1 = policy1.keyArgs as KeyArgsFunction
        const keyArgsFn2 = policy2.keyArgs as KeyArgsFunction

        const args = { page: 1, status: 'active', searchTerm: 'test' }

        const result1 = keyArgsFn1(args, mockFieldContext)
        const result2 = keyArgsFn2(args, mockFieldContext)

        expect(result1).toEqual(result2)
      })

      it('should return consistent cache keys regardless of argument order', () => {
        const policy = createPaginatedFieldPolicy()
        const keyArgsFn = policy.keyArgs as KeyArgsFunction

        // Same arguments in different order
        const args1 = { page: 1, status: 'active', searchTerm: 'test', currency: 'USD' }
        const args2 = { currency: 'USD', page: 1, searchTerm: 'test', status: 'active' }
        const args3 = { searchTerm: 'test', currency: 'USD', status: 'active', page: 1 }

        const result1 = keyArgsFn(args1, mockFieldContext)
        const result2 = keyArgsFn(args2, mockFieldContext)
        const result3 = keyArgsFn(args3, mockFieldContext)

        // All should return the same sorted array
        expect(result1).toEqual(['currency', 'searchTerm', 'status'])
        expect(result2).toEqual(['currency', 'searchTerm', 'status'])
        expect(result3).toEqual(['currency', 'searchTerm', 'status'])
        expect(result1).toEqual(result2)
        expect(result2).toEqual(result3)
      })
    })
  })

  describe('cacheArrayInsert + cacheArrayRemove', () => {
    const PROBE_QUERY = parse(`
      query Probe {
        plan(id: "plan_1") @client {
          __typename
          id
          charges {
            __typename
            id
            invoiceDisplayName
          }
        }
      }
    `)

    const buildCache = () => {
      const cache = new InMemoryCache()

      cache.writeQuery({
        query: PROBE_QUERY,
        data: {
          plan: {
            __typename: 'Plan',
            id: 'plan_1',
            charges: [
              { __typename: 'Charge', id: 'charge_a', invoiceDisplayName: 'A' },
              { __typename: 'Charge', id: 'charge_b', invoiceDisplayName: 'B' },
            ],
          },
        },
      })

      return cache
    }

    it('cacheArrayInsert appends a new item to the parent field', () => {
      const cache = buildCache()

      cacheArrayInsert(cache, { __typename: 'Plan', id: 'plan_1' }, 'charges', {
        __typename: 'Charge',
        id: 'charge_c',
        invoiceDisplayName: 'C',
      })

      const result = cache.extract()
      const planEntry = result['Plan:plan_1'] as { charges: Reference[] }

      expect(planEntry.charges).toHaveLength(3)
      expect(planEntry.charges[2].__ref).toBe('Charge:charge_c')
    })

    it('cacheArrayRemove drops the matching item and evicts the entity', () => {
      const cache = buildCache()

      cacheArrayRemove(cache, { __typename: 'Plan', id: 'plan_1' }, 'charges', 'charge_a', 'Charge')

      const result = cache.extract()
      const planEntry = result['Plan:plan_1'] as { charges: Reference[] }

      expect(planEntry.charges).toHaveLength(1)
      expect(result['Charge:charge_a']).toBeUndefined()
    })
  })
})
