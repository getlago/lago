import { RoleItem } from '~/core/constants/roles'

import { mapPermissionsFromRole } from './mapPermissionsFromRole'

export const mapFromApiToForm = (role: RoleItem | undefined) => {
  return {
    name: role?.name ? role.name : '',
    code: role?.code ? role.code : '',
    description: role?.description ? role.description : '',
    permissions: mapPermissionsFromRole(role),
  }
}
