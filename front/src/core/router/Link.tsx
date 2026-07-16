import { forwardRef } from 'react'
// eslint-disable-next-line lago/no-direct-rrd-nav-import
import { LinkProps, Link as RRLink, useParams } from 'react-router-dom'

import { prependOrgSlug } from './utils/prependOrgSlug'

/**
 * Slug-aware `<Link>` wrapper.
 *
 * Transparently prepends `/${organizationSlug}` to absolute string `to` props
 * so call sites keep writing `<Link to="/customers">` while the rendered href
 * ends up `/${slug}/customers`. Pass-through for the same cases as the
 * `useNavigate` wrapper (root `/`, NEVER_SLUG_PREFIXES, already-prefixed,
 * object form, missing slug).
 */
export const Link = forwardRef<HTMLAnchorElement, LinkProps>(({ to, ...props }, ref) => {
  // `useParams()` can return undefined outside a Router context (e.g. some tests).
  // Use optional access so rendering never throws there.
  const params = useParams<{ organizationSlug?: string }>()
  const organizationSlug = params?.organizationSlug

  const resolved = typeof to === 'string' ? prependOrgSlug(to, organizationSlug) : to

  return <RRLink ref={ref} to={resolved} {...props} />
})

Link.displayName = 'Link'
