import { useApolloClient, useReactiveVar } from '@apollo/client'
import * as Sentry from '@sentry/react'
import { lazy, Suspense, useEffect } from 'react'
import { Outlet, useParams } from 'react-router-dom'

import { Spinner } from '~/components/designSystem/Spinner'
import { switchCurrentOrganization } from '~/core/apolloClient'
import {
  currentOrganizationVar,
  getPersistedOrganizationSlug,
  locationHistoryVar,
  setCurrentOrganizationId,
  setPersistedOrganizationSlug,
} from '~/core/apolloClient/reactiveVars'
import { useLocation, useNavigate } from '~/core/router'
import { LEGACY_APP_PATH_SEGMENTS } from '~/core/router/legacyPaths'
import { resolveOrgSlug } from '~/core/router/utils/orgSlug'
import { useIsAuthenticated } from '~/hooks/auth/useIsAuthenticated'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { hasIframeParams } from '~/hooks/useIframeConfig'

const Error404 = lazy(() => import('~/pages/Error404'))

/**
 * Slug-migration Sentry events use a named `Error` subclass + `captureException`
 * (instead of `captureMessage`) so Sentry's issue title generator picks up the
 * meaningful `{name}: {message}` pair instead of the topmost stack frame from
 * the synthetic stacktrace it attaches to messages (which renders as
 * `commitHookEffectListMount` because we capture from inside a `useEffect`).
 */
class SlugMigrationEvent extends Error {
  constructor(name: string, message: string) {
    super(message)
    this.name = name
  }
}

/** Sentry `mode` tag — distinguishes which recovery branch resolved the slug. */
type RecoveryMode = 'single-org' | 'multi-org-iframe' | 'multi-org'

const OrganizationLayout = () => {
  const { organizationSlug } = useParams<{ organizationSlug: string }>()
  const { currentUser, loading } = useCurrentUser()
  const { isAuthenticated } = useIsAuthenticated()
  const location = useLocation()
  const navigate = useNavigate()
  const client = useApolloClient()

  const currentOrgId = useReactiveVar(currentOrganizationVar)

  const org = currentUser?.memberships.find(
    (m) => m.organization.slug === organizationSlug,
  )?.organization

  // Auto-recovery for legacy pre-migration paths (e.g. `/customers`).
  const isLegacyPath = LEGACY_APP_PATH_SEGMENTS.has(organizationSlug ?? '')

  // Single-membership recovery — UNCHANGED.
  const soleMembershipSlug =
    currentUser?.memberships.length === 1
      ? currentUser.memberships[0]?.organization.slug
      : undefined

  const isIframeContext = hasIframeParams(location.search)

  // Multi-membership recovery — applies when `soleMembershipSlug` is undefined
  // (i.e., user has ≥2 memberships). Resolves via the in-memory org var
  // (`null` here on a legacy slug-less path) → `memberships[0]` fallback.
  const multiMembershipRecoverySlug = !soleMembershipSlug ? resolveOrgSlug(currentUser) : undefined

  const recoveredSlug = soleMembershipSlug ?? multiMembershipRecoverySlug

  const shouldAutoRecoverLegacyPath = !loading && !org && isLegacyPath && !!recoveredSlug

  // If currentOrgId already exists and differs from org.id, the user switched org
  // (e.g. browser back after org switch). In that case, call switchCurrentOrganization
  // to clear the Apollo cache — otherwise stale data from the previous org leaks.
  useEffect(() => {
    if (org?.id) {
      if (currentOrgId && currentOrgId !== org.id) {
        switchCurrentOrganization(client, org.id)
      } else {
        setCurrentOrganizationId(org.id)
      }
      // Remember the last used org slug — the only org-related LS write. Read
      // by `RootRedirect` at `/` to pick a landing slug when the URL has none.
      setPersistedOrganizationSlug(org.slug)
    }
  }, [org?.id, org?.slug, currentOrgId, client])

  // Auto-recover legacy paths universally. Runs in an effect (not render) to
  // avoid React's "cannot update during render" warning when navigation
  // triggers a parent re-render. `replace` keeps history clean — the legacy
  // URL never gets a back-button entry.
  //
  // Two Sentry events may fire here:
  //
  // 1. `legacy_url_auto_recovered` (info) — always, when recovery happens.
  //    The `mode` tag (`single-org` / `multi-org-iframe` / `multi-org`) marks
  //    which recovery branch resolved the slug, for analytics.
  // 2. `slug_migration_missed_link` (error) — additionally, when the previous
  //    in-app path was slug-prefixed. This is the developer-actionable signal
  //    that an in-app link wasn't migrated to the slug wrapper. Auto-recovery
  //    silences the user-facing 404, but we keep this signal so the bug
  //    remains visible in Sentry and dev alerts can fire on it.
  useEffect(() => {
    if (!shouldAutoRecoverLegacyPath) return

    navigate(`/${recoveredSlug}${location.pathname}${location.search}${location.hash}`, {
      replace: true,
      skipSlugPrepend: true,
    })

    // Sentry `mode` tag — purely analytical, distinguishes which recovery
    // branch resolved the slug.
    const recoveryMode = (): RecoveryMode => {
      if (soleMembershipSlug) return 'single-org'
      if (isIframeContext) return 'multi-org-iframe'
      return 'multi-org'
    }

    // Sentry groups by `exception.type` (= `Error.name`), so each
    // `SlugMigrationEvent` subclass name yields its own issue with the
    // correct level. The `feature: 'slug-migration'` tag is the unified
    // search/alert handle across all migration events.
    Sentry.captureException(
      new SlugMigrationEvent('SlugMigrationAutoRecovered', 'legacy_url_auto_recovered'),
      {
        level: 'info',
        tags: {
          feature: 'slug-migration',
          attemptedSlug: organizationSlug ?? '',
          recoveredToSlug: recoveredSlug ?? '',
          mode: recoveryMode(),
        },
        extra: { fullPath: location.pathname },
      },
    )

    // Detect missed-migration in-app links. `previousPath` is read from
    // `locationHistoryVar` which records pathnames the user navigated through;
    // if the previous one starts with the current org's slug, the user was
    // already inside the app and a non-migrated link sent them to a
    // slug-less path. That's a real bug — emit `error` so it's actionable.
    const previousLocations = locationHistoryVar()
    const previousPath = previousLocations[0]?.pathname
    // Use the persisted last-used slug to guess the org the user was on (the
    // var is null on a legacy slug-less path); analytics-only signal.
    const persistedSlug = getPersistedOrganizationSlug()
    const currentOrg = currentUser?.memberships?.find(
      (m) => m.organization.slug === persistedSlug,
    )?.organization
    const isMissedMigration = currentOrg?.slug && previousPath?.startsWith(`/${currentOrg.slug}/`)

    if (isMissedMigration) {
      Sentry.captureException(
        new SlugMigrationEvent('SlugMigrationMissedLink', 'slug_migration_missed_link'),
        {
          level: 'error',
          tags: {
            feature: 'slug-migration',
            attemptedSlug: organizationSlug ?? '',
            source: 'missed_migration',
          },
          extra: {
            fullPath: location.pathname,
            previousPath: previousPath || null,
            currentOrgId: currentOrg?.id,
          },
        },
      )
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [shouldAutoRecoverLegacyPath])

  if (!isAuthenticated) return null

  if (loading && !org) return <Spinner />

  if (org) {
    if (currentOrgId !== org.id) return <Spinner />

    return <Outlet />
  }

  // Render a spinner while the auto-recover effect navigates — prevents a
  // one-frame `<Error404 />` flash before the URL updates.
  if (shouldAutoRecoverLegacyPath) return <Spinner />

  return (
    <Suspense fallback={<Spinner />}>
      <Error404 />
    </Suspense>
  )
}

export default OrganizationLayout
