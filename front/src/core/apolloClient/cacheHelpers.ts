import { ApolloCache, FieldPolicy, Reference } from '@apollo/client'

import { CollectionMetadata } from '~/generated/graphql'

type ParentEntity = { __typename: string; id: string }

type PaginatedCollection = {
  metadata: CollectionMetadata
  collection: Record<string, unknown>[]
}

/**
 * Merges paginated collection results.
 * - If incoming is page 1, replace existing data
 * - Otherwise, append incoming items to existing collection
 */
export const mergePaginatedCollection = (
  existing: PaginatedCollection,
  incoming: PaginatedCollection,
) => {
  if (!incoming?.metadata?.currentPage || incoming?.metadata?.currentPage === 1) {
    return incoming
  }

  return {
    ...incoming,
    collection: [...(existing?.collection || []), ...(incoming.collection || [])],
  }
}

/**
 * Creates a standard field policy for paginated queries.
 *
 * This policy automatically includes all query arguments in the cache key,
 * EXCEPT pagination parameters (page, limit, offset). This means:
 * - Different filters create separate cache entries
 * - Developers don't need to manually specify which args to track
 * - New query arguments are automatically included
 *
 * @param additionalExclusions - Additional argument names to exclude from cache key
 *
 * @example
 * ```typescript
 * // In cache.ts
 * invoices: createPaginatedFieldPolicy()
 * // Automatically caches separately for different status, searchTerm, currency, etc.
 * // But shares cache for different pages of the same filters
 * ```
 */
export const createPaginatedFieldPolicy = (additionalExclusions: string[] = []): FieldPolicy => ({
  keyArgs(args) {
    // If no args, return false to use single shared cache entry
    if (!args) return false

    // Standard pagination args that should NOT affect cache key
    const excludedArgs = new Set(['page', 'limit', 'offset', ...additionalExclusions])

    // Return sorted array of arg keys to include in cache key
    // Sorting ensures consistent cache keys regardless of argument order
    // Apollo will automatically hash the values
    return Object.keys(args)
      .filter((key) => !excludedArgs.has(key))
      .sort((a, b) => a.localeCompare(b))
  },
  merge: mergePaginatedCollection,
})

/**
 * Appends an item to a plain-array field on a normalized parent entity.
 *
 * Use for non-paginated array fields (e.g. `Plan.charges`, `Plan.fixedCharges`) when a
 * granular mutation returns the newly-created child and you need to surface it in the
 * cached parent without refetching. For paginated `{ metadata, collection }` shapes,
 * use the field policy from `createPaginatedFieldPolicy` instead.
 */
export const cacheArrayInsert = (
  cache: ApolloCache<unknown>,
  parent: ParentEntity,
  field: string,
  newItem: Reference | object,
) => {
  cache.modify({
    id: cache.identify(parent),
    fields: {
      [field]: (
        existing: unknown,
        {
          toReference,
        }: {
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          toReference: (o: any) => Reference | undefined
        },
      ) => {
        const list = (existing as readonly unknown[] | undefined) ?? []
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const ref = toReference(newItem as any)

        return [...list, ref ?? newItem]
      },
    },
  })
}

/**
 * Removes an item from a plain-array field on a normalized parent entity and evicts the
 * orphaned entity. Use for non-paginated array fields when a delete mutation returns the
 * id of the destroyed child. For paginated `{ metadata, collection }` shapes use
 * `evictFromCache` instead.
 */
export const cacheArrayRemove = (
  cache: ApolloCache<unknown>,
  parent: ParentEntity,
  field: string,
  itemId: string,
  itemTypename: string,
) => {
  cache.modify({
    id: cache.identify(parent),
    fields: {
      [field]: (
        existing: unknown,
        {
          readField,
        }: {
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          readField: (k: string, ref: any) => unknown
        },
      ) => {
        const list = (existing as readonly Reference[] | undefined) ?? []

        return list.filter((ref) => readField('id', ref) !== itemId)
      },
    },
  })
  cache.evict({ id: cache.identify({ __typename: itemTypename, id: itemId }) })
  cache.gc()
}
