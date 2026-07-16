import { gql, WatchQueryFetchPolicy } from '@apollo/client'

import { useGetWebhookEndpointQuery } from '~/generated/graphql'

gql`
  query getWebhookEndpoint($id: ID!) {
    webhookEndpoint(id: $id) {
      id
      name
      webhookUrl
      signatureAlgo
      eventTypes
    }
  }
`

type UseWebhookEndpointProps = {
  id: string
  skip?: boolean
  fetchPolicy?: WatchQueryFetchPolicy
}

export const useWebhookEndpoint = ({ id, skip, fetchPolicy }: UseWebhookEndpointProps) => {
  const { data, loading, refetch } = useGetWebhookEndpointQuery({
    variables: { id },
    skip: !id || skip,
    fetchPolicy,
    nextFetchPolicy: fetchPolicy,
  })

  return {
    webhook: data?.webhookEndpoint,
    loading,
    refetch,
  }
}
