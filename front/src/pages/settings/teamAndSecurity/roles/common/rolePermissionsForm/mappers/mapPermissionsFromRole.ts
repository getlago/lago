import { RoleItem } from '~/core/constants/roles'
import { PermissionEnum } from '~/generated/graphql'
import { allPermissions } from '~/pages/settings/teamAndSecurity/roles/common/permissionsConst'
import { PermissionName } from '~/pages/settings/teamAndSecurity/roles/common/permissionsTypes'

export const mapPermissionsFromRole = (
  role: RoleItem | undefined,
): Record<PermissionName, boolean> => {
  return allPermissions.reduce<Record<PermissionName, boolean>>(
    (acc, permissionName) => {
      acc[permissionName] = role
        ? role.permissions.includes(PermissionEnum[permissionName]) || role.admin
        : false

      return acc
    },
    {} as Record<PermissionName, boolean>,
  )
}
