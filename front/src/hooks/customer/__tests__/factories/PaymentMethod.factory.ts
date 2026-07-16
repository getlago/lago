import { PaymentMethodsQuery, ProviderTypeEnum } from '~/generated/graphql'
import { PaymentMethodItem } from '~/hooks/customer/usePaymentMethodsList'

export const createMockPaymentMethod = (
  overrides: Partial<PaymentMethodItem> = {},
): PaymentMethodItem => {
  return {
    __typename: 'PaymentMethod',
    id: 'pm_001',
    providerMethodId: 'pm_001',
    isDefault: false,
    paymentProviderCode: 'stripe',
    paymentProviderCustomerId: 'cus_001',
    paymentProviderType: ProviderTypeEnum.Stripe,
    paymentProviderName: null,
    createdAt: '2024-01-15T10:00:00Z',
    deletedAt: null,
    details: {
      __typename: 'PaymentMethodDetails',
      brand: 'visa',
      expirationYear: '2025',
      expirationMonth: '12',
      last4: '4242',
      type: 'card',
    },
    ...overrides,
  } as PaymentMethodItem
}

const DEFAULT_PAYMENT_METHODS: PaymentMethodItem[] = [
  createMockPaymentMethod({
    id: 'pm_001',
    providerMethodId: 'pm_001',
    isDefault: true,
    details: {
      __typename: 'PaymentMethodDetails',
      brand: 'visa',
      expirationYear: '2025',
      expirationMonth: '12',
      last4: '4242',
      type: 'card',
    },
  }),
  createMockPaymentMethod({
    id: 'pm_002',
    providerMethodId: 'pm_002',
    isDefault: false,
    details: {
      __typename: 'PaymentMethodDetails',
      brand: 'mastercard',
      expirationYear: '2026',
      expirationMonth: '06',
      last4: '8888',
      type: 'card',
    },
  }),
]

const createMockPaymentMethodsData = (
  paymentMethods: PaymentMethodItem[] = DEFAULT_PAYMENT_METHODS,
): PaymentMethodsQuery['paymentMethods'] => {
  return {
    __typename: 'PaymentMethodCollection',
    collection: paymentMethods,
  }
}

export const createMockPaymentMethodsQueryResponse = (
  paymentMethods: PaymentMethodItem[] = DEFAULT_PAYMENT_METHODS,
): PaymentMethodsQuery => {
  return {
    __typename: 'Query',
    paymentMethods: createMockPaymentMethodsData(paymentMethods),
  }
}
