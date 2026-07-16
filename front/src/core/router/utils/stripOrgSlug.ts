/**
 * Returns `pathname` with the leading `/${organizationSlug}` stripped, so
 * slug-unaware patterns (route constants, `tab.link`, `exclude` lists) can
 * be compared against it via `matchPath` or equality.
 *
 * Inverse of `prependOrgSlug`. Used by:
 *  - the `useLocation` wrapper (current pathname)
 *  - `useLocationHistory.getPreviousLocation` (historical pathnames from
 *    `locationHistoryVar`)
 *
 * Pass-through when:
 *  - no org slug available
 *  - pathname does not start with `/${organizationSlug}`
 *
 * When the stripped result would be empty (pathname === `/${organizationSlug}`),
 * returns `/`.
 */
export const stripOrgSlug = (pathname: string, organizationSlug: string | undefined): string => {
  const prefix = `/${organizationSlug}`

  if (!organizationSlug || (pathname !== prefix && !pathname.startsWith(`${prefix}/`))) {
    return pathname
  }

  return pathname.slice(prefix.length) || '/'
}
