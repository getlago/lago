import { gql } from '@apollo/client'

import { RoleItem } from '~/core/constants/roles'
import { RoleFragmentFragmentDoc, useGetRolesListQuery } from '~/generated/graphql'

gql`
  query getRolesList {
    roles {
      ...RoleFragment
    }
  }
  ${RoleFragmentFragmentDoc}
`

const SYSTEM_ROLES_ORDER = ['Admin', 'Finance', 'Manager']

export const useRolesList = (): {
  roles: Array<RoleItem>
  isLoadingRoles: boolean
} => {
  const { data, loading } = useGetRolesListQuery()

  const sortedRoles = [...(data?.roles || [])].sort((a, b) => {
    const aIndex = SYSTEM_ROLES_ORDER.indexOf(a.name)
    const bIndex = SYSTEM_ROLES_ORDER.indexOf(b.name)

    // Both are system roles - sort by defined order
    if (aIndex !== -1 && bIndex !== -1) {
      return aIndex - bIndex
    }
    // Only a is a system role - a comes first
    if (aIndex !== -1) {
      return -1
    }
    // Only b is a system role - b comes first
    if (bIndex !== -1) {
      return 1
    }
    // Neither are system roles - keep original order
    return 0
  })

  return {
    roles: sortedRoles,
    isLoadingRoles: loading,
  }
}
