import { LinkedPaymentProvider } from '~/components/customers/types'

export const createMockLinkedPaymentProvider = (
  overrides: Partial<LinkedPaymentProvider> = {},
): LinkedPaymentProvider => {
  const defaultProvider: LinkedPaymentProvider = {
    __typename: 'StripeProvider',
    id: 'provider_001',
    name: 'Stripe',
    code: 'stripe',
  }

  return { ...defaultProvider, ...overrides }
}
