import { gql } from '@apollo/client'

import { useGetAllMembersForFilterQuery } from '~/generated/graphql'

gql`
  query getAllMembersForFilter($page: Int, $limit: Int) {
    memberships(page: $page, limit: $limit) {
      collection {
        id
        user {
          id
          email
        }
      }
    }
  }
`

export const useGetAllMembers = () => {
  const { data, loading } = useGetAllMembersForFilterQuery({
    variables: { limit: 500 },
  })

  return {
    memberships: data?.memberships?.collection || [],
    loading,
  }
}
