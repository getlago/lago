import { gql } from '@apollo/client'
import { useEffect, useState } from 'react'

import { RoleItem, systemRoles } from '~/core/constants/roles'
import { RoleFragmentFragmentDoc, useGetRoleQuery } from '~/generated/graphql'
import { usePermissions } from '~/hooks/usePermissions'

import './roleFragment'

gql`
  query getRole($id: ID!) {
    role(id: $id) {
      ...RoleFragment
    }
  }

  ${RoleFragmentFragmentDoc}
`

export const useRoleDetails = ({
  roleId,
}: {
  roleId: string | undefined
}): {
  role: RoleItem | undefined
  isLoadingRole: boolean
  isSystem: boolean
  canBeDuplicated: boolean
  canBeEdited: boolean
  canBeDeleted: boolean
} => {
  const { hasPermissions } = usePermissions()

  const [isSystem, setIsSystem] = useState(false)
  const [canBeDuplicated, setCanBeDuplicated] = useState(false)
  const [canBeEdited, setCanBeEdited] = useState(false)
  const [canBeDeleted, setCanBeDeleted] = useState(false)

  const { data, loading: isLoadingRole } = useGetRoleQuery({
    variables: { id: roleId ?? '' },
    skip: !roleId,
  })

  useEffect(() => {
    if (isLoadingRole || !data?.role) {
      return
    }

    setIsSystem(systemRoles.includes(data.role.name))

    setCanBeDuplicated(hasPermissions(['rolesCreate']))
    setCanBeEdited(hasPermissions(['rolesUpdate']))
    setCanBeDeleted(data.role.memberships.length === 0 && hasPermissions(['rolesDelete']))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [data?.role, isLoadingRole])

  return {
    role: data?.role || undefined,
    isLoadingRole,
    isSystem,
    canBeDuplicated,
    canBeEdited,
    canBeDeleted,
  }
}
