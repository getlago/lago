import { CreateRoleInput, PermissionEnum } from '~/generated/graphql'

import { RoleCreateEditFormValues } from '../validationSchema'

export const mapFromFormToApi = (formValues: RoleCreateEditFormValues): CreateRoleInput => {
  const permissions =
    Object.entries(formValues.permissions).reduce<PermissionEnum[]>((acc, [key, value]) => {
      if (value) {
        acc.push(PermissionEnum[key as keyof typeof PermissionEnum])
      }

      return acc
    }, []) || []

  return {
    name: formValues.name,
    code: formValues.code,
    description: formValues.description,
    permissions,
  }
}
