import { PaymentProvidersListForCustomerMainInfosQuery } from '~/generated/graphql'

export type LinkedPaymentProvider =
  | NonNullable<
      PaymentProvidersListForCustomerMainInfosQuery['paymentProviders']
    >['collection'][number]
  | undefined
