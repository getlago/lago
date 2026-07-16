import { ApolloClient, NormalizedCacheObject } from '@apollo/client'
import { CachePersistor, LocalForageWrapper } from 'apollo3-cache-persist'
import localForage from 'localforage'
import { matchPath } from 'react-router-dom'

import { CUSTOMER_PORTAL_ROUTE } from '~/core/router/paths/customerPortal'

import { cache } from './cache'

const KEY_PREFIX = 'apollo-cache-persist-lago-'

let persistor: CachePersistor<NormalizedCacheObject> | null = null

const isCustomerPortalContext = () =>
  !!matchPath(`${CUSTOMER_PORTAL_ROUTE}/*`, window.location.pathname)

// storage.purge() only removes the current key. Blobs left by previous app
// versions (different version suffix) must be cleaned manually so old deploys
// don't leave org data at rest forever. Best-effort — never block boot on it.
const purgeStaleVersionedCaches = async (currentKey: string) => {
  try {
    const keys = await localForage.keys()

    await Promise.all(
      keys
        .filter((key) => key.startsWith(KEY_PREFIX) && key !== currentKey)
        .map((key) => localForage.removeItem(key)),
    )
  } catch {
    // ignore — stale-cache cleanup must never prevent the app from starting
  }
}

// Called once at client init. In customer-portal context we skip persistence
// entirely: the portal is public, token-scoped and single-customer, and must
// never restore the shared admin blob into memory nor write into it. The
// in-memory cache still works normally for the portal session.
export const setupCachePersistor = async (appVersion: string) => {
  if (isCustomerPortalContext()) {
    return null
  }

  const currentKey = `${KEY_PREFIX}${appVersion}`

  await purgeStaleVersionedCaches(currentKey)

  persistor = new CachePersistor({
    cache,
    storage: new LocalForageWrapper(localForage),
    key: currentKey,
  })

  // The constructor does not restore (unlike the persistCache helper), so we
  // restore explicitly.
  await persistor.restore()

  return persistor
}

// Wipe the persisted blob from IndexedDB. No-op if setup was skipped (portal).
export const purgePersistedCache = async () => {
  await persistor?.purge()
}

// Full teardown for authenticated contexts (logout, org switch): empty the
// in-memory cache, then wipe the at-rest blob — in that order.
export const resetPersistedCache = async (client: ApolloClient<object>) => {
  await client.clearStore()
  await purgePersistedCache()
}

// Stop persisting without deleting the blob. Used when a portal is entered via
// same-tab client-side navigation (persistor already live with the admin key):
// prevents portal data from leaking into the admin blob while leaving that blob
// intact.
export const pausePersistence = () => {
  persistor?.pause()
}
