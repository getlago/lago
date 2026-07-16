import { generatePath } from 'react-router-dom'

import { NewAnalyticsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  ANALYTIC_ROUTE,
  ANALYTIC_TABS_ROUTE,
  CUSTOMERS_LIST_ROUTE,
  FORBIDDEN_ROUTE,
} from '~/core/router'
import { LEGACY_APP_PATH_SEGMENTS } from '~/core/router/legacyPaths'
import { ensureSlugPrefix, pathHasValidSlug, resolveOrgSlug } from '~/core/router/utils/orgSlug'
import { getRouteForPermission } from '~/core/router/utils/permissionRouteMap'
import { CurrentUserInfosFragment } from '~/generated/graphql'
import { TMembershipPermissions } from '~/hooks/usePermissions'

type CurrentUser = CurrentUserInfosFragment | undefined

type SavedLocation = {
  pathname: string
  search?: string
  hash?: string
}

export type ResolveRedirectInput = {
  currentUser: CurrentUser
  ssoRedirectPath: string | undefined
  savedLocation: SavedLocation | undefined
  hasPermissions: (permissions: Array<keyof TMembershipPermissions>) => boolean
  findFirstViewPermission: () => keyof TMembershipPermissions | null
  hasAccessToAnalyticsDashboardsFeature: boolean
}

export type ResolveRedirectResult = {
  /**
   * Absolute string target OR a Location-like object (used when restoring
   * a saved location from router state, so React Router preserves any
   * additional fields like `state`).
   */
  to: string | SavedLocation
  /**
   * `true` when the resolution consumed `ssoRedirectPath` from LS — Home is
   * responsible for draining the LS key after this returns.
   */
  consumesSsoLs: boolean
}

/**
 * Pure resolver: given the user/auth/permission inputs, returns where Home
 * should redirect. No React, no side effects (LS read happens in the caller
 * and is passed in via `ssoRedirectPath`).
 *
 * Resolution priority:
 *   1. `ssoRedirectPath` — drained by caller after success.
 *   2. `savedLocation` (router-state `from`) — validated against the user's
 *      memberships to avoid stale-org leaks; legacy slug-less paths get
 *      prepended with the resolved slug for ALL users (single-org and
 *      multi-org), matching the universal auto-recovery in
 *      `OrganizationLayout`.
 *   3. Permission-based default (analytics → customers → first view route).
 *   4. `FORBIDDEN_ROUTE` fallback.
 *
 * Returns `null` only when the user has no resolvable slug — caller should
 * navigate to `FORBIDDEN_ROUTE` directly. Every other path returns a target.
 */
export const resolveRedirectTarget = (
  input: ResolveRedirectInput,
): ResolveRedirectResult | null => {
  const {
    currentUser,
    ssoRedirectPath,
    savedLocation,
    hasPermissions,
    findFirstViewPermission,
    hasAccessToAnalyticsDashboardsFeature,
  } = input

  const slug = resolveOrgSlug(currentUser)

  if (!slug) {
    return { to: FORBIDDEN_ROUTE, consumesSsoLs: false }
  }

  // 1. SSO redirect from localStorage (set by auth guard or OAuth callback).
  if (ssoRedirectPath) {
    return {
      to: ensureSlugPrefix(ssoRedirectPath, slug, currentUser),
      consumesSsoLs: true,
    }
  }

  // 2. Router-state `from` — preserved across same-tab login flows.
  if (savedLocation && savedLocation.pathname !== '/') {
    // Validate the slug in the saved path belongs to one of the user's orgs.
    // Prevents stale path leaks: logout + login with a different org would
    // otherwise carry the old org's path through router state.
    const savedSlug = savedLocation.pathname.split('/')[1]
    const belongsToCurrentUser = currentUser?.memberships?.some(
      (m) => m.organization.slug === savedSlug,
    )

    if (belongsToCurrentUser) {
      return { to: savedLocation, consumesSsoLs: false }
    }

    const isLegacySegment = LEGACY_APP_PATH_SEGMENTS.has(savedSlug ?? '')
    const isSlugLessLegacyPath =
      isLegacySegment && !pathHasValidSlug(savedLocation.pathname, currentUser)

    if (isSlugLessLegacyPath) {
      const search = savedLocation.search || ''
      const hash = savedLocation.hash || ''

      return {
        to: `/${slug}${savedLocation.pathname}${search}${hash}`,
        consumesSsoLs: false,
      }
    }
  }

  // 3. Permission-based default.
  const canSeeAnalytics = hasPermissions(['analyticsView', 'dataApiView'])

  if (canSeeAnalytics && !hasAccessToAnalyticsDashboardsFeature) {
    return { to: `/${slug}${ANALYTIC_ROUTE}`, consumesSsoLs: false }
  }

  if (canSeeAnalytics && hasAccessToAnalyticsDashboardsFeature) {
    return {
      to: `/${slug}${generatePath(ANALYTIC_TABS_ROUTE, {
        tab: NewAnalyticsTabsOptionsEnum.revenueStreams,
      })}`,
      consumesSsoLs: false,
    }
  }

  if (hasPermissions(['customersView'])) {
    return { to: `/${slug}${CUSTOMERS_LIST_ROUTE}`, consumesSsoLs: false }
  }

  const firstViewPermission = findFirstViewPermission()
  const routeForPermission = getRouteForPermission(firstViewPermission)

  if (routeForPermission) {
    return {
      to: ensureSlugPrefix(routeForPermission, slug, currentUser),
      consumesSsoLs: false,
    }
  }

  // 4. No accessible route.
  return { to: FORBIDDEN_ROUTE, consumesSsoLs: false }
}
