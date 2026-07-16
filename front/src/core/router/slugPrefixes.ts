/**
 * Paths that must NEVER receive the org slug prefix.
 *
 * Used by the `useNavigate` and `<Link>` wrappers (and `Table.tsx` for
 * `window.open`) to skip slug injection on routes that live outside
 * `/:organizationSlug`.
 *
 * The check is `startsWith`, so `/login` covers `/login/okta` too.
 * Logout goes through `logOut(client)` in cacheUtils (never `navigate`),
 * so no logout route is listed.
 */
export const NEVER_SLUG_PREFIXES = ['/customer-portal', '/forbidden', '/404', '/login']
