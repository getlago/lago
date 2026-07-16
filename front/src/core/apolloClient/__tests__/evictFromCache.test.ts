import { ApolloClient, InMemoryCache } from '@apollo/client'
import { parse } from 'graphql'

import { evictFromCache } from '../evictFromCache'

// Use parse() instead of gql`` to avoid graphql-codegen picking up these fake queries
const LIST_QUERY = parse(`
  query getItems {
    items {
      collection {
        id
        name
      }
      metadata {
        currentPage
        totalPages
      }
    }
  }
`)

const DETAIL_QUERY = parse(`
  query getItem($id: ID!) {
    item(id: $id) {
      id
      name
    }
  }
`)

const SECOND_LIST_QUERY = parse(`
  query getOtherItems {
    otherItems {
      collection {
        id
        name
      }
    }
  }
`)

function createTestClient() {
  const cache = new InMemoryCache()
  const client = new ApolloClient({ cache, link: undefined as never })

  return client
}

function seedCache(client: ApolloClient<object>) {
  client.cache.writeQuery({
    query: LIST_QUERY,
    data: {
      items: {
        __typename: 'ItemCollection',
        collection: [
          { __typename: 'Item', id: 'item-1', name: 'First' },
          { __typename: 'Item', id: 'item-2', name: 'Second' },
          { __typename: 'Item', id: 'item-3', name: 'Third' },
        ],
        metadata: { __typename: 'Metadata', currentPage: 1, totalPages: 1 },
      },
    },
  })
}

describe('evictFromCache', () => {
  describe('GIVEN a cache with entities in a paginated list', () => {
    describe('WHEN evicting a single entity', () => {
      it('THEN should remove the entity from the normalized cache', () => {
        const client = createTestClient()

        seedCache(client)

        evictFromCache(client, {
          id: 'item-2',
          __typename: 'Item',
          listFieldName: 'items',
          listQueryDocument: LIST_QUERY,
        })

        const evicted = client.cache.identify({ id: 'item-2', __typename: 'Item' }) as string

        expect(client.cache.extract()[evicted]).toBeUndefined()
      })

      it('THEN should remove the entity from the list collection', () => {
        const client = createTestClient()

        seedCache(client)

        evictFromCache(client, {
          id: 'item-2',
          __typename: 'Item',
          listFieldName: 'items',
          listQueryDocument: LIST_QUERY,
        })

        const data = client.cache.readQuery({ query: LIST_QUERY })

        expect((data as { items: { collection: { id: string }[] } }).items.collection).toHaveLength(
          2,
        )
        expect(
          (data as { items: { collection: { id: string }[] } }).items.collection.map((i) => i.id),
        ).toEqual(['item-1', 'item-3'])
      })

      it('THEN should preserve metadata in the list', () => {
        const client = createTestClient()

        seedCache(client)

        evictFromCache(client, {
          id: 'item-2',
          __typename: 'Item',
          listFieldName: 'items',
          listQueryDocument: LIST_QUERY,
        })

        const data = client.cache.readQuery({ query: LIST_QUERY }) as {
          items: { metadata: { currentPage: number; totalPages: number } }
        }

        expect(data.items.metadata.currentPage).toBe(1)
        expect(data.items.metadata.totalPages).toBe(1)
      })
    })

    describe('WHEN the entity id does not exist in the cache', () => {
      it('THEN should not throw and leave the cache unchanged', () => {
        const client = createTestClient()

        seedCache(client)

        const before = client.cache.readQuery({ query: LIST_QUERY })

        evictFromCache(client, {
          id: 'nonexistent',
          __typename: 'Item',
          listFieldName: 'items',
          listQueryDocument: LIST_QUERY,
        })

        const after = client.cache.readQuery({ query: LIST_QUERY })

        expect(after).toEqual(before)
      })
    })

    describe('WHEN the list field does not exist in the cache', () => {
      it('THEN should not throw', () => {
        const client = createTestClient()

        seedCache(client)

        expect(() => {
          evictFromCache(client, {
            id: 'item-1',
            __typename: 'Item',
            listFieldName: 'nonExistentField',
            listQueryDocument: LIST_QUERY,
          })
        }).not.toThrow()
      })
    })
  })

  describe('GIVEN multiple list fields', () => {
    describe('WHEN evicting with an array of listFieldNames', () => {
      it('THEN should remove the entity from all specified list fields', () => {
        const client = createTestClient()

        seedCache(client)

        // Also seed a second list
        client.cache.writeQuery({
          query: SECOND_LIST_QUERY,
          data: {
            otherItems: {
              __typename: 'OtherItemCollection',
              collection: [
                { __typename: 'Item', id: 'item-1', name: 'First' },
                { __typename: 'Item', id: 'item-2', name: 'Second' },
              ],
            },
          },
        })

        evictFromCache(client, {
          id: 'item-2',
          __typename: 'Item',
          listFieldName: ['items', 'otherItems'],
          listQueryDocument: [LIST_QUERY, SECOND_LIST_QUERY],
        })

        const listData = client.cache.readQuery({ query: LIST_QUERY }) as {
          items: { collection: { id: string }[] }
        }
        const otherData = client.cache.readQuery({ query: SECOND_LIST_QUERY }) as {
          otherItems: { collection: { id: string }[] }
        }

        expect(listData.items.collection.map((i) => i.id)).toEqual(['item-1', 'item-3'])
        expect(otherData.otherItems.collection.map((i) => i.id)).toEqual(['item-1'])
      })
    })
  })

  describe('GIVEN a detail query field referencing the entity', () => {
    describe('WHEN evicting that entity', () => {
      it('THEN should null out the root field (present, not missing) so the diff stays complete', () => {
        const client = createTestClient()

        seedCache(client)

        // Seed the detail query field: ROOT_QUERY.item({"id":"item-2"}) -> Item:item-2
        client.cache.writeQuery({
          query: DETAIL_QUERY,
          variables: { id: 'item-2' },
          data: { item: { __typename: 'Item', id: 'item-2', name: 'Second' } },
        })

        evictFromCache(client, {
          id: 'item-2',
          __typename: 'Item',
          listFieldName: 'items',
          listQueryDocument: LIST_QUERY,
        })

        const rootQuery = client.cache.extract().ROOT_QUERY as Record<string, unknown>
        const detailFieldKey = Object.keys(rootQuery).find(
          (key) => key.startsWith('item(') && key.includes('item-2'),
        )

        // Field is present and explicitly null - not removed, not a dangling reference.
        expect(detailFieldKey).toBeDefined()
        expect(rootQuery[detailFieldKey as string]).toBeNull()
      })

      it('THEN the detail query should read back complete (item: null), preventing a cache-first refetch', () => {
        const client = createTestClient()

        seedCache(client)

        client.cache.writeQuery({
          query: DETAIL_QUERY,
          variables: { id: 'item-2' },
          data: { item: { __typename: 'Item', id: 'item-2', name: 'Second' } },
        })

        evictFromCache(client, {
          id: 'item-2',
          __typename: 'Item',
          listFieldName: 'items',
          listQueryDocument: LIST_QUERY,
        })

        // A complete diff is what stops Apollo's reobserveCacheFirst from going to network.
        const diff = client.cache.diff({
          query: DETAIL_QUERY,
          variables: { id: 'item-2' },
          optimistic: false,
          returnPartialData: true,
        })

        expect(diff.complete).toBe(true)
        expect((diff.result as { item: unknown }).item).toBeNull()
      })
    })
  })

  describe('GIVEN active query watchers', () => {
    describe('WHEN a detail query watcher exists', () => {
      it('THEN should suppress the detail watcher notification', () => {
        const client = createTestClient()

        seedCache(client)

        const detailCallback = jest.fn()

        // Subscribe to detail query watcher
        client.cache.watch({
          query: DETAIL_QUERY,
          variables: { id: 'item-2' },
          callback: detailCallback,
          optimistic: true,
        })

        // Clear any initial callback calls
        detailCallback.mockClear()

        evictFromCache(client, {
          id: 'item-2',
          __typename: 'Item',
          listFieldName: 'items',
          listQueryDocument: LIST_QUERY,
        })

        expect(detailCallback).not.toHaveBeenCalled()
      })
    })

    describe('WHEN a list query watcher exists', () => {
      it('THEN should allow the list watcher notification', () => {
        const client = createTestClient()

        seedCache(client)

        const listCallback = jest.fn()

        // Subscribe to list query watcher
        client.cache.watch({
          query: LIST_QUERY,
          callback: listCallback,
          optimistic: true,
        })

        // Clear any initial callback calls
        listCallback.mockClear()

        evictFromCache(client, {
          id: 'item-2',
          __typename: 'Item',
          listFieldName: 'items',
          listQueryDocument: LIST_QUERY,
        })

        expect(listCallback).toHaveBeenCalled()
      })
    })
  })
})
