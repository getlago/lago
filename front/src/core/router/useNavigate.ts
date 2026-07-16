import {
  NavigateFunction,
  NavigateOptions as RRNavigateOptions,
  To,
  useParams,
  // eslint-disable-next-line lago/no-direct-rrd-nav-import
  useNavigate as useRRNavigate,
} from 'react-router-dom'

import { prependOrgSlug } from './utils/prependOrgSlug'

interface NavigateOptions extends RRNavigateOptions {
  /**
   * When true, the wrapper does NOT prepend the current org slug.
   * Use when the caller already builds a slug-prefixed path for a
   * DIFFERENT org than the one in `useParams()` — e.g. the
   * OrganizationSwitcher navigating to the newly-selected org.
   */
  skipSlugPrepend?: boolean
}

type SlugAwareNavigate = (to: To | number, options?: NavigateOptions) => void

/**
 * Slug-aware `useNavigate` wrapper.
 *
 * Transparently prepends `/${organizationSlug}` to absolute string targets
 * so call sites keep writing `navigate('/customers')` while the URL ends up
 * `/${slug}/customers`. Pass-through for:
 * - `navigate(-1)` / any number (history delta)
 * - `navigate({ search, pathname })` object form
 * - targets starting with any `NEVER_SLUG_PREFIXES` entry
 * - targets already starting with `/${organizationSlug}/` (no double-prepend)
 * - the root path `/` (HOME_ROUTE lives outside org scope)
 * - `skipSlugPrepend: true`
 */
export const useNavigate = (): SlugAwareNavigate => {
  const rrNavigate: NavigateFunction = useRRNavigate()
  // `useParams()` can return undefined outside a Router context (e.g. some tests).
  // Use optional access so calls never throw there.
  const params = useParams<{ organizationSlug?: string }>()
  const organizationSlug = params?.organizationSlug

  return (to, options) => {
    if (typeof to === 'number') {
      rrNavigate(to)
      return
    }

    const { skipSlugPrepend, ...rrOptions } = options || {}

    const finalTo =
      !skipSlugPrepend && typeof to === 'string' ? prependOrgSlug(to, organizationSlug) : to

    // Only forward options when the caller actually provided any — otherwise
    // we'd change the call shape to `rrNavigate(path, {})`, which leaks into
    // tests that assert on exact arguments.
    if (options === undefined) {
      rrNavigate(finalTo)
    } else {
      rrNavigate(finalTo, rrOptions)
    }
  }
}
