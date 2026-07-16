import { TMembershipPermissions } from '~/hooks/usePermissions'

import { routes } from '../index'

type PermissionRouteMap = Partial<Record<keyof TMembershipPermissions, string>>

/**
 * Recursively extracts view permission to route mappings from route configs.
 * Prioritizes the first route found for each permission.
 */
const buildPermissionRouteMap = (
  routeConfigs: typeof routes,
  map: PermissionRouteMap = {},
): PermissionRouteMap => {
  for (const route of routeConfigs) {
    // Process children first (depth-first)
    if (route.children) {
      buildPermissionRouteMap(route.children, map)
    }

    // Skip routes without permissions or path
    if ((!route.permissions && !route.permissionsOr) || !route.path) continue

    // Get the first path if it's an array
    const routePath = Array.isArray(route.path) ? route.path[0] : route.path

    // Skip routes with dynamic params (e.g., :customerId) as they need context
    if (routePath.includes(':')) continue

    // Find view permissions in this route (check both AND and OR arrays)
    const andViewPermissions =
      route.permissions?.filter((p) => p.toLowerCase().includes('view')) || []
    const orViewPermissions =
      route.permissionsOr?.filter((p) => p.toLowerCase().includes('view')) || []
    const viewPermissions = [...andViewPermissions, ...orViewPermissions]

    // Map each view permission to the route if not already mapped
    for (const viewPermission of viewPermissions) {
      if (!map[viewPermission]) {
        map[viewPermission] = routePath
      }
    }
  }

  return map
}

// Build the map once at module load
let cachedMap: PermissionRouteMap | null = null

export const getPermissionRouteMap = (): PermissionRouteMap => {
  if (!cachedMap) {
    cachedMap = buildPermissionRouteMap(routes)
  }
  return cachedMap
}

export const getRouteForPermission = (
  permission: keyof TMembershipPermissions | null,
): string | null => {
  if (!permission) return null
  return getPermissionRouteMap()[permission] ?? null
}
