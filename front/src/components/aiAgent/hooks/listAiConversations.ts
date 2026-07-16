import { gql } from '@apollo/client'

import { useListAiConversationsQuery } from '~/generated/graphql'

gql`
  query listAiConversations($limit: Int) {
    aiConversations(limit: $limit) {
      collection {
        id
        name
        updatedAt
      }
    }
  }
`

export const useListAiConversations = () => {
  const { data, loading, error } = useListAiConversationsQuery({
    variables: {
      limit: 3,
    },
  })

  return {
    data,
    loading,
    error,
  }
}
