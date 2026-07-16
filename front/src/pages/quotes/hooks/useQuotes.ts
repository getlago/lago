import { FetchMoreQueryOptions, gql, OperationVariables } from '@apollo/client'

import {
  GetQuotesQuery,
  GetQuotesQueryVariables,
  QuoteListItemFragment,
  useGetQuotesQuery,
} from '~/generated/graphql'

gql`
  fragment QuoteListItem on Quote {
    id
    number
    versions {
      id
      status
      version
    }
    orderType
    createdAt
    customer {
      id
      displayName
    }
  }

  query getQuotes(
    $page: Int
    $limit: Int
    $statuses: [StatusEnum!]
    $customers: [ID!]
    $numbers: [String!]
    $fromDate: ISO8601Date
    $toDate: ISO8601Date
    $owners: [ID!]
    $orderTypes: [OrderTypeEnum!]
  ) {
    quotes(
      page: $page
      limit: $limit
      statuses: $statuses
      customers: $customers
      numbers: $numbers
      fromDate: $fromDate
      toDate: $toDate
      owners: $owners
      orderTypes: $orderTypes
    ) {
      metadata {
        currentPage
        totalPages
        totalCount
      }
      collection {
        ...QuoteListItem
      }
    }
  }
`

interface UseQuotesReturn {
  quotes: QuoteListItemFragment[]
  metadata: GetQuotesQuery['quotes']['metadata'] | undefined
  loading: boolean
  error: Error | undefined
  fetchMore:
    | ((
        fetchMoreOptions: FetchMoreQueryOptions<OperationVariables, GetQuotesQuery>,
      ) => Promise<unknown>)
    | undefined
}

export const useQuotes = (
  variables?: Omit<GetQuotesQueryVariables, 'limit' | 'page'>,
): UseQuotesReturn => {
  const { data, loading, error, fetchMore } = useGetQuotesQuery({
    variables: {
      limit: 20,
      ...variables,
    },
    notifyOnNetworkStatusChange: true,
    fetchPolicy: 'network-only',
    nextFetchPolicy: 'network-only',
  })

  return {
    quotes: data?.quotes?.collection || [],
    metadata: data?.quotes?.metadata,
    loading,
    error,
    fetchMore,
  }
}
