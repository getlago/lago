import { ApolloClient } from '@apollo/client'

const mockCtor = jest.fn()
const mockRestore = jest.fn()
const mockPurge = jest.fn()
const mockPause = jest.fn()
const mockKeys = jest.fn()
const mockRemoveItem = jest.fn()

jest.mock('apollo3-cache-persist', () => ({
  CachePersistor: function CachePersistorMock(options: unknown) {
    mockCtor(options)

    return { restore: mockRestore, purge: mockPurge, pause: mockPause }
  },
  LocalForageWrapper: function LocalForageWrapperMock(storage: unknown) {
    return { storage }
  },
}))

jest.mock('localforage', () => ({
  __esModule: true,
  default: {
    keys: (...args: unknown[]) => mockKeys(...args),
    removeItem: (...args: unknown[]) => mockRemoveItem(...args),
  },
}))

jest.mock('../cache', () => ({ cache: { id: 'mock-cache' } }))

const CURRENT_KEY = 'apollo-cache-persist-lago-1.0.0'
const STALE_KEY = 'apollo-cache-persist-lago-0.9.0'
const UNRELATED_KEY = 'some-other-localforage-key'

const loadModule = () => import('../cachePersistor')

describe('cachePersistor', () => {
  beforeEach(() => {
    jest.resetModules()
    jest.clearAllMocks()
    mockRestore.mockResolvedValue(undefined)
    mockPurge.mockResolvedValue(undefined)
    mockRemoveItem.mockResolvedValue(undefined)
    mockKeys.mockResolvedValue([])
    window.history.pushState({}, '', '/')
  })

  describe('setupCachePersistor', () => {
    describe('GIVEN a customer-portal URL', () => {
      it('THEN should skip persistence entirely (no persistor, no restore)', async () => {
        window.history.pushState({}, '', '/customer-portal/some-token')

        const { setupCachePersistor } = await loadModule()
        const result = await setupCachePersistor('1.0.0')

        expect(result).toBeNull()
        expect(mockCtor).not.toHaveBeenCalled()
        expect(mockRestore).not.toHaveBeenCalled()
      })
    })

    describe('GIVEN a non-portal URL', () => {
      it('THEN should purge only stale version-keyed blobs, keep the current and unrelated keys, then restore', async () => {
        mockKeys.mockResolvedValue([CURRENT_KEY, STALE_KEY, UNRELATED_KEY])

        const { setupCachePersistor } = await loadModule()
        const result = await setupCachePersistor('1.0.0')

        expect(mockRemoveItem).toHaveBeenCalledTimes(1)
        expect(mockRemoveItem).toHaveBeenCalledWith(STALE_KEY)
        expect(mockRemoveItem).not.toHaveBeenCalledWith(CURRENT_KEY)
        expect(mockRemoveItem).not.toHaveBeenCalledWith(UNRELATED_KEY)

        expect(mockCtor).toHaveBeenCalledWith(expect.objectContaining({ key: CURRENT_KEY }))
        expect(mockRestore).toHaveBeenCalledTimes(1)
        expect(result).not.toBeNull()
      })

      it('THEN should still set up the persistor when stale-cache cleanup fails', async () => {
        mockKeys.mockRejectedValue(new Error('IndexedDB unavailable'))

        const { setupCachePersistor } = await loadModule()
        const result = await setupCachePersistor('1.0.0')

        expect(result).not.toBeNull()
        expect(mockRestore).toHaveBeenCalledTimes(1)
      })
    })
  })

  describe('resetPersistedCache', () => {
    it('THEN should clear the in-memory store BEFORE purging the persisted blob', async () => {
      const { setupCachePersistor, resetPersistedCache } = await loadModule()

      await setupCachePersistor('1.0.0')

      const callOrder: string[] = []

      mockPurge.mockImplementation(async () => {
        callOrder.push('purge')
      })

      const client = {
        clearStore: jest.fn().mockImplementation(async () => {
          callOrder.push('clearStore')
        }),
      } as unknown as ApolloClient<object>

      await resetPersistedCache(client)

      expect(callOrder).toEqual(['clearStore', 'purge'])
    })
  })

  describe('purgePersistedCache', () => {
    it('THEN should be a no-op when persistence was skipped (portal context)', async () => {
      window.history.pushState({}, '', '/customer-portal/some-token')

      const { setupCachePersistor, purgePersistedCache } = await loadModule()

      await setupCachePersistor('1.0.0')
      await purgePersistedCache()

      expect(mockPurge).not.toHaveBeenCalled()
    })
  })

  describe('pausePersistence', () => {
    it('THEN should pause the persistor write trigger', async () => {
      const { setupCachePersistor, pausePersistence } = await loadModule()

      await setupCachePersistor('1.0.0')
      pausePersistence()

      expect(mockPause).toHaveBeenCalledTimes(1)
    })
  })
})
