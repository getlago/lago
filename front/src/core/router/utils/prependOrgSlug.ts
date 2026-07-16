import { NEVER_SLUG_PREFIXES } from '../slugPrefixes'

/**
 * Returns `path` with `/${organizationSlug}` prepended when the target is
 * an absolute in-app path that should be slug-scoped. Pass-through otherwise.
 *
 * Single source of truth for the guard logic used by:
 *  - `useNavigate` wrapper (string targets)
 *  - `<Link>` wrapper
 *  - `Table.tsx` for `window.open` (which bypasses the wrappers)
 *
 * Skipped (pass-through) when:
 *  - no org slug available (outside `/:organizationSlug`)
 *  - path is not absolute (`./foo`, `foo`, empty, etc.)
 *  - path is exactly `/` (HOME_ROUTE lives outside the org scope)
 *  - path is already slug-prefixed (prevents double prepend, e.g. after
 *    `navigate(location.pathname)`)
 *  - path starts with a `NEVER_SLUG_PREFIXES` entry (public routes:
 *    `/login`, `/customer-portal`, `/forbidden`, `/404`)
 */
export const prependOrgSlug = (path: string, organizationSlug: string | undefined): string => {
  if (
    !organizationSlug ||
    !path.startsWith('/') ||
    path === '/' ||
    path.startsWith(`/${organizationSlug}/`) ||
    path === `/${organizationSlug}` ||
    NEVER_SLUG_PREFIXES.some((prefix) => path.startsWith(prefix))
  ) {
    return path
  }

  return `/${organizationSlug}${path}`
}
