import { FetchMoreQueryOptions, gql, OperationVariables } from '@apollo/client'

import {
  GetOrdersQuery,
  GetOrdersQueryVariables,
  OrderListItemFragment,
  useGetOrdersQuery,
} from '~/generated/graphql'

gql`
  fragment OrderListItem on Order {
    id
    number
    status
    executionMode
    executedAt
    customer {
      id
      displayName
      ...QuotePreviewCustomer
    }
    orderForm {
      id
      number
      quote {
        id
        number
        images
        currentVersion {
          id
          version
          ...QuotePreviewVersion
        }
      }
    }
  }

  query getOrders(
    $page: Int
    $limit: Int
    $quoteNumber: [String!]
    $status: [OrderStatusEnum!]
    $customerId: [ID!]
    $number: [String!]
    $ownerId: [ID!]
    $executionMode: [OrderExecutionModeEnum!]
    $executedAtFrom: ISO8601DateTime
    $executedAtTo: ISO8601DateTime
  ) {
    orders(
      page: $page
      limit: $limit
      quoteNumber: $quoteNumber
      status: $status
      customerId: $customerId
      number: $number
      ownerId: $ownerId
      executionMode: $executionMode
      executedAtFrom: $executedAtFrom
      executedAtTo: $executedAtTo
    ) {
      metadata {
        currentPage
        totalPages
        totalCount
      }
      collection {
        ...OrderListItem
      }
    }
  }
`

interface UseOrdersReturn {
  orders: OrderListItemFragment[]
  metadata: GetOrdersQuery['orders']['metadata'] | undefined
  loading: boolean
  error: Error | undefined
  fetchMore:
    | ((
        fetchMoreOptions: FetchMoreQueryOptions<OperationVariables, GetOrdersQuery>,
      ) => Promise<unknown>)
    | undefined
}

export const useOrders = (
  variables?: Omit<GetOrdersQueryVariables, 'limit' | 'page'>,
): UseOrdersReturn => {
  const { data, loading, error, fetchMore } = useGetOrdersQuery({
    variables: {
      limit: 20,
      ...variables,
    },
    notifyOnNetworkStatusChange: true,
    fetchPolicy: 'network-only',
    nextFetchPolicy: 'network-only',
  })

  return {
    orders: data?.orders?.collection || [],
    metadata: data?.orders?.metadata,
    loading,
    error,
    fetchMore,
  }
}
