import { gql } from '@apollo/client'

import { useCreateAiConversationMutation } from '~/generated/graphql'

gql`
  mutation createAiConversation($input: CreateAiConversationInput!) {
    createAiConversation(input: $input) {
      id
      name
    }
  }
`

export const useCreateAiConversation = () => {
  const [createAiConversation, { loading, error }] = useCreateAiConversationMutation()

  return {
    createAiConversation,
    loading,
    error,
  }
}
