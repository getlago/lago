import { gql } from '@apollo/client'

import { addToast } from '~/core/apolloClient'
import {
  MembershipPermissionsFragmentDoc,
  useRevokeMembershipMutation,
  useUpdateMembershipRoleMutation,
} from '~/generated/graphql'

gql`
  fragment MemberForEditRoleForDialog on Membership {
    id
    roles
    user {
      id
      email
    }
    ...MembershipPermissions
  }

  mutation updateMembershipRole($input: UpdateMembershipInput!) {
    updateMembership(input: $input) {
      id
      ...MemberForEditRoleForDialog
    }
  }

  ${MembershipPermissionsFragmentDoc}

  mutation revokeMembership($input: RevokeMembershipInput!) {
    revokeMembership(input: $input) {
      id
    }
  }
`

export const useMembershipActions = () => {
  const [updateMembershipRole] = useUpdateMembershipRoleMutation({
    onCompleted(res) {
      if (res?.updateMembership) {
        addToast({
          severity: 'success',
          translateKey: 'text_664f3562b7caf600e5246883',
        })
      }
    },
    refetchQueries: ['getMembers'],
  })

  const [revokeMembership] = useRevokeMembershipMutation({
    onCompleted(data) {
      if (data?.revokeMembership) {
        addToast({
          translateKey: 'text_63208c711ce25db78140755d',
          severity: 'success',
        })
      }
    },

    update(cache, { data }) {
      if (!data?.revokeMembership) return

      const cacheId = cache.identify({
        id: data?.revokeMembership.id,
        __typename: 'Membership',
      })

      cache.evict({ id: cacheId })
    },
  })

  return {
    updateMembershipRole,
    revokeMembership,
  }
}
