import { gql } from '@apollo/client'

import { GetOrderFormDetailsQuery, useGetOrderFormDetailsQuery } from '~/generated/graphql'

gql`
  query getOrderFormDetails($id: ID!) {
    orderForm(id: $id) {
      id
      number
      status
      expiresAt
      signedDocumentUrl
      customer {
        id
        displayName
        ...QuotePreviewCustomer
      }
      quote {
        id
        number
        images
        orderType
        currentVersion {
          id
          version
          ...QuotePreviewVersion
        }
      }
    }
  }
`

interface UseOrderFormDetailsReturn {
  orderForm: GetOrderFormDetailsQuery['orderForm']
  loading: boolean
  error: Error | undefined
}

export const useOrderFormDetails = (id?: string): UseOrderFormDetailsReturn => {
  const { data, loading, error } = useGetOrderFormDetailsQuery({
    variables: { id: id || '' },
    skip: !id,
  })

  return {
    orderForm: data?.orderForm,
    loading,
    error,
  }
}
