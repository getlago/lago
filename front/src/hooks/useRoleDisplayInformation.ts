import {
  RoleItem,
  rolesDescriptionMapping,
  rolesNameMapping,
  systemRoles,
} from '~/core/constants/roles'
import { useInternationalization } from '~/hooks/core/useInternationalization'

export type AllowedElements = RoleItem | undefined | { name: string; description?: string }

export const useRoleDisplayInformation = (): {
  getDisplayName: (role: AllowedElements) => string
  getDisplayDescription: (role: AllowedElements) => string
} => {
  const { translate } = useInternationalization()

  const getDisplayName = (role: AllowedElements) => {
    if (!role) return ''

    return systemRoles.includes(role.name)
      ? translate(rolesNameMapping[role.name as keyof typeof rolesNameMapping])
      : role.name
  }

  const getDisplayDescription = (role: AllowedElements) => {
    if (!role) return ''

    if (systemRoles.includes(role.name)) {
      return translate(rolesDescriptionMapping[role.name as keyof typeof rolesDescriptionMapping])
    }

    return role.description ?? ''
  }

  return {
    getDisplayName,
    getDisplayDescription,
  }
}
