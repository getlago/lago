import { gql } from '@apollo/client'

import { InviteForEditRoleForDialogFragmentDoc, useGetInvitesQuery } from '~/generated/graphql'

gql`
  fragment InviteItemForMembersSettings on Invite {
    id
    email
    token
    roles
    organization {
      id
      name
    }
    ...InviteForEditRoleForDialog
  }

  query getInvites($page: Int, $limit: Int) {
    invites(page: $page, limit: $limit) {
      metadata {
        currentPage
        totalPages
        totalCount
      }
      collection {
        ...InviteItemForMembersSettings
      }
    }
  }

  ${InviteForEditRoleForDialogFragmentDoc}
`

export const useGetMembersInvitationList = () => {
  const {
    data: invitesData,
    error: invitesError,
    loading: invitesLoading,
    refetch: invitesRefetch,
    fetchMore: invitesFetchMore,
  } = useGetInvitesQuery({ variables: { limit: 20 }, notifyOnNetworkStatusChange: true })

  return {
    invitations: invitesData?.invites.collection || [],
    metadata: invitesData?.invites.metadata,
    invitesError,
    invitesLoading,
    invitesRefetch,
    invitesFetchMore,
  }
}
