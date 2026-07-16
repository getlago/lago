import { useEffect, useRef } from 'react'

import { Spinner } from '~/components/designSystem/Spinner'
import { useLocation, useNavigate } from '~/core/router'
import { getItemFromLS, removeItemFromLS } from '~/core/utils/localStorage'
import { REDIRECT_AFTER_LOGIN_LS_KEY } from '~/core/utils/localStorageKeys'
import { PremiumIntegrationTypeEnum } from '~/generated/graphql'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissions } from '~/hooks/usePermissions'

import { resolveRedirectTarget } from './utils'

const Home = () => {
  const navigate = useNavigate()
  const location = useLocation()
  const { loading: isUserLoading, currentUser, currentMembership } = useCurrentUser()
  const { hasPermissions, findFirstViewPermission } = usePermissions()
  const { hasOrganizationPremiumAddon, loading: isOrganizationLoading } = useOrganizationInfos()
  const hasAccessToAnalyticsDashboardsFeature = hasOrganizationPremiumAddon(
    PremiumIntegrationTypeEnum.AnalyticsDashboards,
  )

  // Idempotent guard: Home's effect deps (currentUser, currentMembership,
  // hasAccessToAnalyticsDashboardsFeature, ...) resolve at different ticks.
  // Without this latch, the first run consumes the SSO redirect via LS, then
  // a second run fires before unmount with LS now empty → falls through to
  // the default permission-based branch which `replace`-overwrites the
  // intended destination. The ref keeps the guard out of state to avoid
  // re-renders.
  const hasNavigatedRef = useRef(false)

  useEffect(() => {
    if (isUserLoading || isOrganizationLoading || !currentMembership) return
    if (hasNavigatedRef.current) return

    const routerState = location.state as
      { from?: { pathname: string; search?: string; hash?: string } } | null | undefined

    const target = resolveRedirectTarget({
      currentUser,
      ssoRedirectPath: getItemFromLS(REDIRECT_AFTER_LOGIN_LS_KEY) || undefined,
      savedLocation: routerState?.from,
      hasPermissions,
      findFirstViewPermission,
      hasAccessToAnalyticsDashboardsFeature,
    })

    if (!target) return

    if (target.consumesSsoLs) {
      removeItemFromLS(REDIRECT_AFTER_LOGIN_LS_KEY)
    }

    hasNavigatedRef.current = true
    navigate(target.to, { replace: true })
  }, [
    isUserLoading,
    currentUser,
    currentMembership,
    isOrganizationLoading,
    hasPermissions,
    findFirstViewPermission,
    hasAccessToAnalyticsDashboardsFeature,
    navigate,
    location.state,
  ])

  return <Spinner />
}

export default Home
