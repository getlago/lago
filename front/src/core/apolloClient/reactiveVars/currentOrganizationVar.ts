import { makeVar } from '@apollo/client'

import { getItemFromLS, removeItemFromLS, setItemFromLS } from '~/core/utils/localStorage'
import { LAST_USED_ORGANIZATION_LS_KEY } from '~/core/utils/localStorageKeys'

/**
 * Current organization id (UUID) for THIS tab — in-memory only, derived from
 * the URL slug. `OrganizationLayout` populates it from
 * `useParams().organizationSlug` + `currentUser.memberships` on every
 * authenticated render; the Apollo auth link reads it via
 * `getCurrentOrganizationId()` to set the `x-lago-organization` header.
 *
 * It is NOT seeded from / persisted to localStorage: the slug is the source of
 * truth, and a query with no current org id must not be sent (the backend
 * `organization` resolver rejects a missing header).
 */
export const currentOrganizationVar = makeVar<string | null>(null)

export const getCurrentOrganizationId = (): string | null => currentOrganizationVar()

export const setCurrentOrganizationId = (id: string | null): void => {
  currentOrganizationVar(id)
}

/**
 * Last used organization SLUG, persisted in localStorage. This is the ONLY
 * org-related use of localStorage and it never feeds the auth header: it is
 * read solely by the root redirect (`RootRedirect`) to choose a landing slug
 * when the URL has none, and written by `OrganizationLayout` whenever an org
 * route is entered. Always re-validated against the user's memberships before
 * use, so a stale/foreign value is harmless.
 */
export const getPersistedOrganizationSlug = (): string | null =>
  getItemFromLS(LAST_USED_ORGANIZATION_LS_KEY) || null

export const setPersistedOrganizationSlug = (slug: string | null): void => {
  if (slug) {
    setItemFromLS(LAST_USED_ORGANIZATION_LS_KEY, slug)
  } else {
    removeItemFromLS(LAST_USED_ORGANIZATION_LS_KEY)
  }
}
