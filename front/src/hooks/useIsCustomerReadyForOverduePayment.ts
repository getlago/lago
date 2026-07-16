import { ApolloError, gql } from '@apollo/client'
import { useParams } from 'react-router-dom'

import { useGetCustomerOverdueInvoicesReadyForPaymentProcessingQuery } from '~/generated/graphql'

gql`
  query getCustomerOverdueInvoicesReadyForPaymentProcessing($id: ID!) {
    invoices(paymentOverdue: true, customerId: $id) {
      collection {
        readyForPaymentProcessing
      }
    }
  }
`

interface UseIsCustomerReadyForOverduePaymentReturn {
  isCustomerReadyForOverduePayment: boolean
  error: ApolloError | undefined
  loading: boolean
}

export const useIsCustomerReadyForOverduePayment =
  (): UseIsCustomerReadyForOverduePaymentReturn => {
    const { customerId } = useParams()
    const { data, loading, error } = useGetCustomerOverdueInvoicesReadyForPaymentProcessingQuery({
      variables: { id: customerId ?? '' },
      skip: !customerId,
    })

    const invoices = data?.invoices
    const invoicesNotReadyForPaymentProcessing =
      invoices?.collection?.filter((invoice) => !invoice.readyForPaymentProcessing) || []

    const isCustomerReadyForOverduePayment =
      !loading && !error && invoicesNotReadyForPaymentProcessing.length === 0

    return {
      isCustomerReadyForOverduePayment,
      loading,
      error,
    }
  }
