import { useEffect, useRef } from 'react'

import { Spinner } from '~/components/designSystem/Spinner'
import { getPersistedOrganizationSlug } from '~/core/apolloClient/reactiveVars'
import { FORBIDDEN_ROUTE, useLocation, useNavigate } from '~/core/router'
import { getItemFromLS } from '~/core/utils/localStorage'
import { REDIRECT_AFTER_LOGIN_LS_KEY } from '~/core/utils/localStorageKeys'
import { useCurrentUser } from '~/hooks/useCurrentUser'

/**
 * Root redirect hub (`/`), rendered OUTSIDE the `:organizationSlug` scope.
 *
 * Its only job is to resolve a landing org slug and redirect to `/${slug}`. It
 * performs NO org-scoped query and reads NO org-scoped data (permissions,
 * feature flags, premium addons) — at the root the auth header is null, so any
 * org-scoped query would be rejected by the backend. All of that is resolved by
 * the org-scoped `Home` (the `/:organizationSlug` index) once `OrganizationLayout`
 * has set the org context from the URL slug. Keeping the root org-data-free is
 * what makes the in-memory (non-LS-seeded) org var safe.
 *
 * Landing slug priority (each candidate validated against the user's accessible
 * memberships): slug of the saved `from` location → slug of the SSO redirect
 * path → persisted "last used" slug → first accessible membership.
 * `REDIRECT_AFTER_LOGIN_LS_KEY` is left untouched (the org-scoped `Home`
 * consumes it) and `location.state` is forwarded so the saved `from` survives
 * the bounce.
 */
const RootRedirect = () => {
  const navigate = useNavigate()
  const location = useLocation()
  const { loading: isUserLoading, currentUser } = useCurrentUser()
  const hasNavigatedRef = useRef(false)

  useEffect(() => {
    if (isUserLoading || !currentUser) return
    if (hasNavigatedRef.current) return

    const accessibleMemberships = (currentUser.memberships || []).filter(
      (membership) => membership.organization.accessibleByCurrentSession,
    )

    if (!accessibleMemberships.length) {
      hasNavigatedRef.current = true
      navigate(FORBIDDEN_ROUTE, { replace: true })
      return
    }

    const isAccessibleSlug = (slug?: string): slug is string =>
      !!slug && accessibleMemberships.some((m) => m.organization.slug === slug)

    const routerState = location.state as { from?: { pathname?: string } } | null | undefined
    const savedSlug = routerState?.from?.pathname?.split('/')[1]
    const ssoSlug = (getItemFromLS(REDIRECT_AFTER_LOGIN_LS_KEY) || undefined)?.split('/')[1]
    const persistedSlug = getPersistedOrganizationSlug() || undefined

    const targetSlug =
      [savedSlug, ssoSlug, persistedSlug].find(isAccessibleSlug) ??
      accessibleMemberships[0].organization.slug

    hasNavigatedRef.current = true
    navigate(`/${targetSlug}`, { replace: true, state: location.state, skipSlugPrepend: true })
  }, [isUserLoading, currentUser, location.state, navigate])

  return <Spinner />
}

export default RootRedirect
