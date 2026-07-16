import { gql } from '@apollo/client'

import { PaymentMethodsQuery, usePaymentMethodsQuery } from '~/generated/graphql'

gql`
  query PaymentMethods($externalCustomerId: ID!, $withDeleted: Boolean) {
    paymentMethods(externalCustomerId: $externalCustomerId, withDeleted: $withDeleted) {
      collection {
        id
        isDefault
        paymentProviderCode
        paymentProviderCustomerId
        paymentProviderType
        paymentProviderName
        providerMethodId
        deletedAt
        createdAt
        details {
          brand
          expirationYear
          expirationMonth
          last4
          type
        }
      }
    }
  }
`

export type PaymentMethodList = PaymentMethodsQuery['paymentMethods']['collection']
export type PaymentMethodItem = PaymentMethodList[number]

interface UsePaymentMethodsListReturn {
  loading: boolean
  error: boolean
  data: PaymentMethodList
  refetch: () => Promise<unknown>
}

interface UsePaymentMethodsListArgs {
  externalCustomerId?: string
  withDeleted?: boolean
  skip?: boolean
}

type UsePaymentMethodsList = (args: UsePaymentMethodsListArgs) => UsePaymentMethodsListReturn

export const usePaymentMethodsList: UsePaymentMethodsList = ({
  externalCustomerId = '',
  withDeleted = true,
  skip = false,
}) => {
  const { data, loading, error, refetch } = usePaymentMethodsQuery({
    variables: {
      externalCustomerId,
      withDeleted,
    },
    skip: skip || !externalCustomerId,
  })

  return {
    loading,
    error: !!error,
    data: data?.paymentMethods?.collection || [],
    refetch,
  }
}
