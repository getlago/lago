import { envGlobalVar } from '~/core/apolloClient'
import { AppEnvEnum } from '~/core/constants/globalTypes'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import {
  groupNameMapping,
  hiddenPermissions,
  permissionDescriptionMapping,
  permissionGroupMapping,
} from '~/pages/settings/teamAndSecurity/roles/common/permissionsConst'
import {
  PermissionGrouping,
  PermissionName,
} from '~/pages/settings/teamAndSecurity/roles/common/permissionsTypes'

export const useGetPermissionGrouping = (
  permissions: Array<PermissionName>,
): { permissionGrouping: PermissionGrouping } => {
  const { translate } = useInternationalization()

  const getPermissionDescription = (permissionName: PermissionName): string => {
    const translationKey = permissionDescriptionMapping[permissionName]

    if (!translationKey) {
      const { appEnv } = envGlobalVar()

      if (appEnv === AppEnvEnum.development) {
        // eslint-disable-next-line no-console
        console.warn(`Missing permission description mapping for: ${permissionName}`)
      }

      return permissionName
    }

    return translate(translationKey) || permissionName
  }

  const getPermissionGroupDisplayName = (groupKey: string): string => {
    return translate(groupNameMapping[groupKey]) || translate('text_636d86cd9fd41b93c35bf1c7') // 'Other'
  }

  const hiddenPermissionsSet = new Set(hiddenPermissions)
  const filteredPermissions = permissions.filter(
    (permission) => !hiddenPermissionsSet.has(permission),
  )
  const permissionsSet = new Set(filteredPermissions)
  const allMappedPermissions = new Set(Object.values(permissionGroupMapping).flat())
  const unmappedPermissions = filteredPermissions.filter(
    (permission) => !allMappedPermissions.has(permission),
  )

  const result = Object.entries(permissionGroupMapping).reduce<PermissionGrouping>(
    (acc, [groupKey, groupPermissions]) => {
      const matchingPermissions = groupPermissions.filter((permission) =>
        permissionsSet.has(permission),
      )

      const groupName = getPermissionGroupDisplayName(groupKey)

      acc[groupKey] = {
        name: groupKey,
        displayName: groupName,
        permissions: matchingPermissions.map((permission) => ({
          name: permission,
          description: getPermissionDescription(permission),
        })),
      }

      return acc
    },
    {},
  )

  if (unmappedPermissions.length > 0) {
    const groupName = getPermissionGroupDisplayName('other')

    result.other = {
      name: 'other',
      displayName: groupName,
      permissions: unmappedPermissions.map((permission) => ({
        name: permission,
        description: getPermissionDescription(permission),
      })),
    }
  }

  const permissionGrouping = Object.entries(result).reduce<PermissionGrouping>(
    (acc, [key, group]) => {
      if (group.permissions.length > 0) {
        acc[key] = group
      }
      return acc
    },
    {},
  )

  return {
    permissionGrouping,
  }
}
