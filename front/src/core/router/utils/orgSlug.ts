import { gql } from '@apollo/client'

import {
  getCurrentOrganizationId,
  getPersistedOrganizationSlug,
} from '~/core/apolloClient/reactiveVars'
import { OrgSlugResolverDataFragment } from '~/generated/graphql'

gql`
  fragment OrgSlugResolverData on User {
    memberships {
      id
      organization {
        id
        slug
      }
    }
  }
`

type CurrentUser = OrgSlugResolverDataFragment | undefined

/**
 * Resolves the org slug to land on when the URL has no (valid) slug — e.g. a
 * legacy slug-less path or the user deleting the slug from the URL bar.
 *
 * Priority (each validated against the user's memberships):
 *   1. The in-memory current org (`getCurrentOrganizationId()`) — set per-tab
 *      while navigating inside an org. Correct mid-session and multi-tab safe,
 *      but `null` after a hard reload (the var is not persisted).
 *   2. The persisted "last used" slug (`getPersistedOrganizationSlug()`) — the
 *      only signal that survives a hard reload, so a cold load of a slug-less
 *      path recovers to the org the user was last on instead of `memberships[0]`.
 *   3. Fallback to the first membership's org slug.
 *
 * Returns `undefined` only if the user has no memberships.
 */
export const resolveOrgSlug = (currentUser: CurrentUser): string | undefined => {
  const memberships = currentUser?.memberships

  const currentOrgId = getCurrentOrganizationId()
  const fromCurrentOrg = memberships?.find((m) => m.organization.id === currentOrgId)?.organization
    .slug

  const persistedSlug = getPersistedOrganizationSlug()
  const fromPersisted = memberships?.find((m) => m.organization.slug === persistedSlug)
    ?.organization.slug

  return fromCurrentOrg || fromPersisted || memberships?.[0]?.organization.slug
}

/**
 * Returns true if the path already starts with one of the user's org slugs
 * (e.g. `/acme/customers` when the user is a member of `acme`).
 */
export const pathHasValidSlug = (path: string, currentUser: CurrentUser): boolean =>
  currentUser?.memberships?.some(
    (m) => m.organization.slug && path.startsWith(`/${m.organization.slug}/`),
  ) ?? false

/**
 * Prepends the given slug to the path if the path doesn't already contain
 * a valid user org slug. Used to upgrade legacy pre-migration paths to
 * slug-prefixed URLs.
 */
export const ensureSlugPrefix = (path: string, slug: string, currentUser: CurrentUser): string => {
  if (pathHasValidSlug(path, currentUser)) return path

  return `/${slug}${path.startsWith('/') ? '' : '/'}${path}`
}
