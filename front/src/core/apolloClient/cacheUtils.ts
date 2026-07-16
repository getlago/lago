import { ApolloClient, ApolloQueryResult, gql } from '@apollo/client'

import { removeItemFromLS, setItemFromLS } from '~/core/utils/localStorage'
import {
  CurrentUserFragmentDoc,
  GetCurrentUserInfosForLoginQuery,
  LagoApiError,
} from '~/generated/graphql'
import { DEVTOOL_AUTO_SAVE_KEY, resetDevtoolsNavigation } from '~/hooks/useDeveloperTool'

import { purgePersistedCache, resetPersistedCache } from './cachePersistor'
import {
  addToast,
  AUTH_TOKEN_LS_KEY,
  resetLocationHistoryVar,
  setCurrentOrganizationId,
  TMP_AUTH_TOKEN_LS_KEY,
  updateAuthTokenVar,
  updateCustomerPortalTokenVar,
} from './reactiveVars'

gql`
  fragment CurrentUser on User {
    id
    organizations {
      id
      name
      timezone
      accessibleByCurrentSession
    }
  }
`

// --------------------- Auth utils ---------------------
export const logOut = async (client: ApolloClient<object>, resetLocationHistory?: boolean) => {
  // Reset devtools navigation to prevent stale queries with old transactionIds
  resetDevtoolsNavigation()
  // Cancels active operations
  client.stop()
  // Removes cached data (in-memory + IndexedDB-persisted blob) and prevents
  // active queries re-fetch
  await resetPersistedCache(client)
  updateAuthTokenVar()

  resetLocationHistory && resetLocationHistoryVar()
}

const getCurrentUserOrganization = async (client: ApolloClient<object>, token: string) => {
  try {
    // Set a temporary auth token to query the current user infos
    // We don't want to use the AUTH_TOKEN_LS_KEY as it would means that the user is already authenticated.
    // Here we are logged in but we are not authenticated yet.
    setItemFromLS(TMP_AUTH_TOKEN_LS_KEY, token)

    // Then get the current user infos to query organizations
    const response = await client.query({
      query: gql`
        query getCurrentUserInfosForLogin {
          currentUser {
            id
            ...CurrentUser
          }
        }

        ${CurrentUserFragmentDoc}
      `,
      context: {
        fetchPolicy: 'network-only',
      },
    })

    return response as ApolloQueryResult<GetCurrentUserInfosForLoginQuery>
  } catch {
    return undefined
  } finally {
    // Remove the temporary auth token in any case
    removeItemFromLS(TMP_AUTH_TOKEN_LS_KEY)
  }
}

export const onLogIn = async (client: ApolloClient<object>, token: string) => {
  try {
    const response = await getCurrentUserOrganization(client, token)

    // If no response, it means that the current user could not have been fetched.
    if (!response) {
      throw new Error(LagoApiError.InternalError)
    }

    // Set the auth token. The landing organization is resolved from the URL by
    // `RootRedirect` (saved/SSO path → last-used slug → first accessible
    // membership), so login no longer selects or sets a current org id.
    updateAuthTokenVar(token)
  } catch {
    // If an error occurs, display a toast to inform the user that the login failed
    addToast({
      severity: 'danger',
      translateKey: 'text_622f7a3dc32ce100c46a5154',
    })

    // Remove all local storage items related to the auth
    removeItemFromLS(AUTH_TOKEN_LS_KEY)

    // In case of error, we want to log out the user
    await logOut(client, true)
  }
}

export const switchCurrentOrganization = async (
  client: ApolloClient<object>,
  organizationId: string,
) => {
  // 1. Reset devtools navigation to prevent stale queries with old transactionIds
  resetDevtoolsNavigation()

  // 2. Purge the previous org's IndexedDB-persisted blob so its data isn't left
  //    at rest. Fire-and-forget on purpose: `OrganizationLayout`'s effect
  //    re-enters this function during the slug↔var mismatch window around the
  //    post-switch `navigate`, so the switch path is timing-sensitive. Awaiting
  //    an IndexedDB op here adds latency that stretches that mismatch window and
  //    lets React paint a blank Error404 frame. Backgrounding it keeps the
  //    teardown→resync timing identical to the pre-persistence behaviour (only
  //    `clearStore` awaited). The new org's refetch (step 5) repersists a fresh
  //    blob; `removeItem` resolves long before the network round-trip, so it
  //    won't delete that fresh blob.
  purgePersistedCache().catch(() => {})

  // 3. Cancel in-flight queries scoped to the previous org. If we let them
  //    return after the var change, they'd write old-org data into a cache
  //    that we're about to repopulate for the new org → race.
  client.stop()

  // 4. Clear the cache before updating the org context.
  await client.clearStore()

  // 4b. Update the org id (and LS). The auth link reads from the var, so any
  //    request fired AFTER this line carries the new `x-lago-organization`
  //    header.
  setCurrentOrganizationId(organizationId)

  // 5. Re-fire every active observable query with the new header. Crucial
  //    for the hard-refresh-with-stale-LS path: in that case
  //    `OrganizationLayout`'s gate keeps `Outlet` unmounted, so children
  //    never get a fresh mount that would create new observers — the
  //    observers in `OrganizationLayout` itself (e.g. `useCurrentUser`)
  //    were stopped at step 3 and would otherwise sit dead, leaving the
  //    UI stuck on `loading: true` until a second hard refresh.
  //
  //    Fire-and-forget on purpose: callers (e.g. `OrganizationSwitcher`)
  //    typically navigate to the new org URL right after this resolves,
  //    and we don't want to delay that navigation behind a network
  //    round-trip. The slug-aware gate in `useOrganizationInfos` covers
  //    the brief window where the cache is empty / refetch in flight.
  client.reFetchObservableQueries()

  // 7. Clear other org-specific state
  removeItemFromLS(DEVTOOL_AUTO_SAVE_KEY)
}

export const onAccessCustomerPortal = (token?: string) => {
  updateCustomerPortalTokenVar(token)
}

// --------------------- Omit __typename ---------------------
const omitDeepArrayWalk = (arr: Array<unknown>, key: string): unknown => {
  return arr.map((val) => {
    if (Array.isArray(val)) return omitDeepArrayWalk(val, key)
    // @ts-expect-error: val could be null which would cause type error when passing to omitDeep
    else if (typeof val === 'object') return omitDeep(val, key)
    return val
  })
}

export const omitDeep = (obj: Record<string | number, unknown>, key: string) => {
  const keys = Object.keys(obj)
  const newObj: Record<string | number, unknown> = {}

  keys.forEach((i) => {
    if (i !== key) {
      const val = obj[i]

      if (val instanceof Date) newObj[i] = val
      else if (Array.isArray(val)) newObj[i] = omitDeepArrayWalk(val, key)
      else if (typeof val === 'object' && val !== null)
        // @ts-expect-error: val could be any object type which would cause type error when passing to omitDeep
        newObj[i] = omitDeep(val, key)
      else newObj[i] = val
    }
  })
  return newObj
}
