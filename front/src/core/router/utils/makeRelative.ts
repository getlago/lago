import { CustomRouteObject } from '../types'

/**
 * Strips the leading `/` from a route path so it works as a relative child
 * under a parent dynamic segment (e.g. `:organizationSlug`).
 */
export const stripLeadingSlash = (path: string): string =>
  path.startsWith('/') ? path.slice(1) : path

/**
 * Recursively converts a route array from absolute paths (`/customers`) to
 * relative paths (`customers`) so they can be nested under `:organizationSlug`.
 *
 * Handles both `path: string` and `path: string[]` shapes, and passes through
 * routes without a `path` (layout wrappers, index routes).
 */
export const makeRelative = (routes: CustomRouteObject[]): CustomRouteObject[] =>
  routes.map((route) => {
    let nextPath = route.path

    if (typeof route.path === 'string') {
      nextPath = stripLeadingSlash(route.path)
    } else if (Array.isArray(route.path)) {
      nextPath = route.path.map(stripLeadingSlash)
    }

    return {
      ...route,
      path: nextPath,
      children: route.children ? makeRelative(route.children) : route.children,
    }
  })
