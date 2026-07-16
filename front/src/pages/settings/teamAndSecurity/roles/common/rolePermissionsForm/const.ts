import { allPermissions } from '../permissionsConst'
import { type PermissionName } from '../permissionsTypes'

export const rolePermissionsEmptyValues = allPermissions.reduce(
  (acc, permissionName) => {
    acc[permissionName] = false

    return acc
  },
  {} as Record<PermissionName, boolean>,
)
