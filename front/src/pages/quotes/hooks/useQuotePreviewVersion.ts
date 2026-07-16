import { gql } from '@apollo/client'

import { GetQuotePreviewQuery, useGetQuotePreviewQuery } from '~/generated/graphql'

gql`
  query getQuotePreview($id: ID!) {
    quote(id: $id) {
      id
      number
      images
      orderType
      customer {
        id
        displayName
        ...QuotePreviewCustomer
      }
      versions {
        id
        status
        version
        ...QuotePreviewVersion
      }
    }
  }
`

interface UseQuotePreviewVersionReturn {
  quote: GetQuotePreviewQuery['quote']
  loading: boolean
  error: Error | undefined
}

export const useQuotePreviewVersion = (id?: string): UseQuotePreviewVersionReturn => {
  const { data, loading, error } = useGetQuotePreviewQuery({
    variables: { id: id || '' },
    skip: !id,
  })

  return {
    quote: data?.quote,
    loading,
    error,
  }
}
