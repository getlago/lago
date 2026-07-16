import { gql } from '@apollo/client'
import { useState } from 'react'

import { addToast } from '~/core/apolloClient'
import {
  GetInvitesDocument,
  GetInvitesQuery,
  InviteItemForMembersSettingsFragmentDoc,
  LagoApiError,
  useCreateInviteMutation,
  useRevokeInviteMutation,
  useUpdateInviteRoleMutation,
} from '~/generated/graphql'

gql`
  fragment InviteForEditRoleForDialog on Invite {
    id
    roles
    email
  }

  mutation createInvite($input: CreateInviteInput!) {
    createInvite(input: $input) {
      id
      token
      ...InviteItemForMembersSettings
    }
  }

  ${InviteItemForMembersSettingsFragmentDoc}

  mutation updateInviteRole($input: UpdateInviteInput!) {
    updateInvite(input: $input) {
      id
      ...InviteForEditRoleForDialog
    }
  }

  mutation revokeInvite($input: RevokeInviteInput!) {
    revokeInvite(input: $input) {
      id
    }
  }
`

export const useInviteActions = () => {
  const [inviteToken, setInviteToken] = useState<string>('')

  const [createInvite, { error }] = useCreateInviteMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted(res) {
      if (res?.createInvite?.token) {
        setInviteToken(res.createInvite.token)
      }
    },
    update(cache, { data }) {
      if (!data?.createInvite) return

      const invitesData: GetInvitesQuery | null = cache.readQuery({
        query: GetInvitesDocument,
      })

      cache.writeQuery({
        query: GetInvitesDocument,
        data: {
          invites: {
            metadata: {
              ...invitesData?.invites?.metadata,
              totalCount: (invitesData?.invites?.metadata?.totalCount || 0) + 1,
            },
            collection: [data?.createInvite, ...(invitesData?.invites?.collection || [])],
          },
        },
      })
    },
  })

  const [updateInviteRole] = useUpdateInviteRoleMutation({
    onCompleted(res) {
      if (res?.updateInvite) {
        addToast({
          severity: 'success',
          translateKey: 'text_664f3562b7caf600e5246883',
        })
      }
    },
  })

  const [revokeInvite] = useRevokeInviteMutation({
    onCompleted(data) {
      if (data?.revokeInvite) {
        addToast({
          translateKey: 'text_63208c711ce25db781407523',
          severity: 'success',
        })
      }
    },
    refetchQueries: ['getInvites'],
  })

  return {
    inviteToken,
    setInviteToken,
    createInvite,
    createInviteError: error,
    updateInviteRole,
    revokeInvite,
  }
}
