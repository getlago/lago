import { CheckboxGroup } from '~/components/form/GroupedCheckboxList'

import { useGetPermissionGrouping } from './useGetPermissionGrouping'

import { allPermissions } from '../common/permissionsConst'

export const useRolePermissionsGroups = (): { groups: CheckboxGroup[] } => {
  const { permissionGrouping } = useGetPermissionGrouping(allPermissions)

  // permissionGrouping already has translated displayName and descriptions
  const groups: CheckboxGroup[] = Object.values(permissionGrouping).map((permGroup) => ({
    id: permGroup.name,
    label: permGroup.displayName,
    items: permGroup.permissions.map((permission) => ({
      id: permission.name,
      label: permission.description, // Already translated by useGetPermissionGrouping
    })),
  }))

  return { groups }
}
