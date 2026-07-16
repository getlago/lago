import { gql } from '@apollo/client'

import { QuoteDetailItemFragment, useGetQuoteQuery } from '~/generated/graphql'

gql`
  fragment QuotePreviewVersion on QuoteVersion {
    content
    billingItems
    mentionVariables
  }

  fragment QuotePreviewCustomer on Customer {
    currency
    billingConfiguration {
      documentLocale
    }
  }

  fragment QuoteDetailItem on Quote {
    id
    number
    images
    versions {
      id
      status
      version
      createdAt
    }
    orderType
    createdAt
    customer {
      id
      displayName
      externalId
      netPaymentTerm
      ...QuotePreviewCustomer
      billingEntity {
        id
        code
        name
        netPaymentTerm
      }
    }
    owners {
      id
      email
    }
    subscription {
      id
      name
      externalId
      subscriptionAt
      plan {
        id
        name
      }
    }
    currentVersion {
      id
      status
      version
      currency
      startDate
      endDate
      createdAt
      ...QuotePreviewVersion
    }
  }

  query getQuote($id: ID!) {
    quote(id: $id) {
      ...QuoteDetailItem
    }
  }
`

interface UseQuoteReturn {
  quote: QuoteDetailItemFragment | null | undefined
  loading: boolean
  error: Error | undefined
  refetch: ReturnType<typeof useGetQuoteQuery>['refetch']
}

export const useQuote = (id?: string): UseQuoteReturn => {
  const { data, loading, error, refetch } = useGetQuoteQuery({
    variables: { id: id || '' },
    skip: !id,
  })

  return {
    quote: data?.quote,
    loading,
    error,
    refetch,
  }
}
