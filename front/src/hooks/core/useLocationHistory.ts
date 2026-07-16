import { Location, matchPath, NavigateOptions, useParams } from 'react-router-dom'

import { addLocationToHistory, authTokenVar, locationHistoryVar } from '~/core/apolloClient'
import {
  CustomRouteObject,
  FORBIDDEN_ROUTE,
  HOME_ROUTE,
  LOGIN_ROUTE,
  useNavigate,
} from '~/core/router'
import { stripOrgSlug } from '~/core/router/utils/stripOrgSlug'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { hasIframeParams } from '~/hooks/useIframeConfig'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { TMembershipPermissions, usePermissions } from '~/hooks/usePermissions'

type GoBack = (
  fallback: string,
  options?: {
    // Previous count represents how many location from now you want to go back to
    previousCount?: number
    exclude?: string | string[]
    state?: NavigateOptions['state']
  },
) => void

type UseLocationHistoryReturn = () => {
  onRouteEnter: (routeConfig: CustomRouteObject, location: Location) => void
  goBack: GoBack
}

const getPreviousLocation = ({
  previousCount = -1,
  exclude,
  organizationSlug,
}: {
  previousCount?: number
  exclude?: string | string[]
  organizationSlug?: string
}) => {
  const previousLocations = locationHistoryVar()
  const index = exclude
    ? previousLocations.findIndex((location, i) => {
        if (i < Math.abs(previousCount)) {
          return false
        }

        // History pathnames include the org slug (e.g. `/acme/settings/taxes`),
        // but `exclude` patterns are slug-unaware route constants
        // (e.g. `/settings/taxes`). Strip the slug before matching.
        const strippedPathname = stripOrgSlug(location.pathname, organizationSlug)

        const isExcluded =
          typeof exclude === 'string'
            ? matchPath(exclude, strippedPathname)
            : exclude.some((pathToExclude) => matchPath(pathToExclude, strippedPathname))

        return !isExcluded
      })
    : Math.abs(previousCount)

  return {
    previous: previousLocations[index],
    remainingHistory: index > -1 ? previousLocations.slice(index + 1) : [],
  }
}

const checkRoutePermissions = (
  routeConfig: CustomRouteObject,
  hasPermissions: (permissions: Array<keyof TMembershipPermissions>) => boolean,
  hasPermissionsOr: (permissions: Array<keyof TMembershipPermissions>) => boolean,
): boolean => {
  // No permissions required
  if (!routeConfig.permissions && !routeConfig.permissionsOr) {
    return true
  }

  // Both AND and OR: user must satisfy BOTH conditions
  if (routeConfig.permissions && routeConfig.permissionsOr) {
    return hasPermissions(routeConfig.permissions) && hasPermissionsOr(routeConfig.permissionsOr)
  }

  // Only AND permissions
  if (routeConfig.permissions) {
    return hasPermissions(routeConfig.permissions)
  }

  // Only OR permissions
  return hasPermissionsOr(routeConfig.permissionsOr ?? [])
}

export const useLocationHistory: UseLocationHistoryReturn = () => {
  const navigate = useNavigate()
  // `useParams()` can return undefined outside a Router context (e.g. some tests).
  const params = useParams<{ organizationSlug?: string }>()
  const organizationSlug = params?.organizationSlug
  const { loading: isCurrentUserLoading } = useCurrentUser()
  const { hasPermissions, hasPermissionsOr } = usePermissions()
  const { hasFeatureFlag } = useOrganizationInfos()
  const goBack: GoBack = (fallback, options) => {
    const { previous, remainingHistory } = getPreviousLocation({
      ...(options || {}),
      organizationSlug,
    })

    if (options?.state) {
      navigate(previous || fallback, { state: options.state })
    } else {
      navigate(previous || fallback)
    }

    locationHistoryVar(remainingHistory || [])
  }

  return {
    goBack,
    onRouteEnter: (routeConfig, location) => {
      const isAuthenticated = !!authTokenVar()

      if (routeConfig.onlyPublic && isAuthenticated) {
        /**
         * In case of navigation to a only public route while authenticated
         * Redirect to home, preserving any saved location state from login flow
         */
        navigate(HOME_ROUTE, { state: location.state, replace: true })
      } else if (routeConfig.private && !isAuthenticated) {
        /**
         * In case of navigation to a private route while NOT authenticated
         * Redirect to login and store the intended destination in router state.
         *
         * Iframe params (`?sfdc=true` / `?ifrm=true`) are propagated onto the
         * `/login` URL so `useIframeConfig` (read inside Login.tsx) keeps
         * detecting the embed context and hides Google/Okta buttons. Without
         * this, Salesforce/Hubspot users would see the full SSO UI inside the
         * iframe — Google/Okta auth flows can't complete in an embedded frame
         * (CSP / popup blockers / cookie scoping), only email+password works.
         */
        const loginPath = hasIframeParams(location.search)
          ? `${LOGIN_ROUTE}${location.search}`
          : LOGIN_ROUTE

        navigate(loginPath, {
          state: {
            from: location,
          },
          replace: true,
        })
      } else if (isAuthenticated && !isCurrentUserLoading) {
        const hasRequiredPermissions = checkRoutePermissions(
          routeConfig,
          hasPermissions,
          hasPermissionsOr,
        )

        if (!hasRequiredPermissions) {
          /**
           * In case of navigation to a private route while authenticated but without permission
           * Redirect to forbidden page
           */
          navigate(FORBIDDEN_ROUTE)
        } else if (routeConfig.featureFlag && !hasFeatureFlag(routeConfig.featureFlag)) {
          /**
           * In case of navigation to a route gated by a feature flag that is not active
           * Redirect to home page
           */
          navigate(HOME_ROUTE, { replace: true })
        } else if (!routeConfig?.children && !routeConfig.onlyPublic) {
          /**
           * We add the current location to the history only if :
           * - Current route has no children (to avoid adding Layout route which will result in duplicates)
           * - Current route is not an only public route
           */
          addLocationToHistory(location)
        }
      } else if (!routeConfig?.children && !routeConfig.onlyPublic) {
        // In the invitation for page, once users are logged in, we redirect them to the home page
        if (routeConfig.invitation && isAuthenticated) {
          // We can then safely redirect to the home page.
          navigate(HOME_ROUTE)
        }
        /**
         * We add the current location to the history only if :
         * - Current route has no children (to avoid adding Layout route which will result in duplicates)
         * - Current route is not an only public route
         */
        addLocationToHistory(location)
      }
    },
  }
}
