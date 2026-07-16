import { FetchMoreQueryOptions, gql, OperationVariables } from '@apollo/client'

import {
  GetOrderFormsQuery,
  GetOrderFormsQueryVariables,
  OrderFormListItemFragment,
  useGetOrderFormsQuery,
} from '~/generated/graphql'

gql`
  fragment OrderFormListItem on OrderForm {
    id
    number
    status
    createdAt
    expiresAt
    customer {
      id
      displayName
      ...QuotePreviewCustomer
    }
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

  query getOrderForms(
    $page: Int
    $limit: Int
    $status: [OrderFormStatusEnum!]
    $quoteNumber: [String!]
    $number: [String!]
    $customerId: [ID!]
    $ownerId: [ID!]
    $createdAtFrom: ISO8601DateTime
    $createdAtTo: ISO8601DateTime
  ) {
    orderForms(
      page: $page
      limit: $limit
      status: $status
      quoteNumber: $quoteNumber
      number: $number
      customerId: $customerId
      ownerId: $ownerId
      createdAtFrom: $createdAtFrom
      createdAtTo: $createdAtTo
    ) {
      metadata {
        currentPage
        totalPages
        totalCount
      }
      collection {
        ...OrderFormListItem
      }
    }
  }
`

interface UseOrderFormsReturn {
  orderForms: OrderFormListItemFragment[]
  metadata: GetOrderFormsQuery['orderForms']['metadata'] | undefined
  loading: boolean
  error: Error | undefined
  fetchMore:
    | ((
        fetchMoreOptions: FetchMoreQueryOptions<OperationVariables, GetOrderFormsQuery>,
      ) => Promise<unknown>)
    | undefined
}

export const useOrderForms = (
  variables?: Omit<GetOrderFormsQueryVariables, 'limit' | 'page'>,
): UseOrderFormsReturn => {
  const { data, loading, error, fetchMore } = useGetOrderFormsQuery({
    variables: {
      limit: 20,
      ...variables,
    },
    notifyOnNetworkStatusChange: true,
    fetchPolicy: 'network-only',
    nextFetchPolicy: 'network-only',
  })

  return {
    orderForms: data?.orderForms?.collection || [],
    metadata: data?.orderForms?.metadata,
    loading,
    error,
    fetchMore,
  }
}
