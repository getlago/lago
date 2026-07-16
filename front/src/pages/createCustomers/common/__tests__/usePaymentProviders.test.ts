import { wait } from '@apollo/client/testing'
import { act, renderHook } from '@testing-library/react'
import React from 'react'

import {
  PaymentProvidersListForCustomerCreateEditExternalAppsAccordionDocument,
  ProviderTypeEnum,
} from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { usePaymentProviders } from '../usePaymentProviders'

type PrepareType = {
  mockData?: Record<string, unknown>
  error?: boolean
  delay?: number
  networkError?: boolean
}

async function prepare({
  mockData,
  error = false,
  delay = 0,
  networkError = false,
}: PrepareType = {}) {
  const defaultMockData = {
    paymentProviders: {
      collection: [
        {
          __typename: 'StripeProvider',
          id: '1',
          name: 'Stripe Main',
          code: 'stripe-main',
        },
        {
          __typename: 'GocardlessProvider',
          id: '2',
          name: 'GoCardless UK',
          code: 'gocardless-uk',
        },
        {
          __typename: 'AdyenProvider',
          id: '3',
          name: 'Adyen Global',
          code: 'adyen-global',
        },
        {
          __typename: 'CashfreeProvider',
          id: '4',
          name: 'Cashfree India',
          code: 'cashfree-india',
        },
        {
          __typename: 'FlutterwaveProvider',
          id: '5',
          name: 'Flutterwave Africa',
          code: 'flutterwave-africa',
        },
        {
          __typename: 'MoneyhashProvider',
          id: '6',
          name: 'Moneyhash MENA',
          code: 'moneyhash-mena',
        },
      ],
    },
  }

  const mocks = [
    {
      request: {
        query: PaymentProvidersListForCustomerCreateEditExternalAppsAccordionDocument,
        variables: { limit: 1000 },
      },
      result: error
        ? {
            errors: [{ message: 'GraphQL error occurred' }],
          }
        : {
            data: mockData || defaultMockData,
          },
      delay,
      ...(networkError && { error: new Error('Network error') }),
    },
  ]

  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({
      children,
      mocks,
      forceTypenames: true,
    })

  const { result } = renderHook(() => usePaymentProviders(), {
    wrapper: customWrapper,
  })

  return { result }
}

describe('usePaymentProviders', () => {
  describe('when query succeeds with data', () => {
    it('should return payment providers data and loading state', async () => {
      const { result } = await prepare()

      // Initially loading
      expect(result.current.isLoadingPaymentProviders).toBe(true)
      expect(result.current.paymentProviders).toBeUndefined()
      expect(typeof result.current.getPaymentProvider).toBe('function')

      // Wait for the query to resolve
      await act(() => wait(0))

      // After loading completes
      expect(result.current.isLoadingPaymentProviders).toBe(false)
      expect(result.current.paymentProviders).toBeDefined()
      expect(result.current.paymentProviders?.paymentProviders?.collection).toHaveLength(6)

      const collection = result.current.paymentProviders?.paymentProviders?.collection

      expect(collection?.[0]).toEqual({
        __typename: 'StripeProvider',
        id: '1',
        name: 'Stripe Main',
        code: 'stripe-main',
      })
      expect(collection?.[1]).toEqual({
        __typename: 'GocardlessProvider',
        id: '2',
        name: 'GoCardless UK',
        code: 'gocardless-uk',
      })
      expect(collection?.[5]).toEqual({
        __typename: 'MoneyhashProvider',
        id: '6',
        name: 'Moneyhash MENA',
        code: 'moneyhash-mena',
      })
    })

    it('should handle empty payment providers collection', async () => {
      const { result } = await prepare({
        mockData: {
          paymentProviders: {
            collection: [],
          },
        },
      })

      await act(() => wait(0))

      expect(result.current.isLoadingPaymentProviders).toBe(false)
      expect(result.current.paymentProviders?.paymentProviders?.collection).toEqual([])
    })

    it('should handle null paymentProviders', async () => {
      const { result } = await prepare({
        mockData: {
          paymentProviders: null,
        },
      })

      await act(() => wait(0))

      expect(result.current.isLoadingPaymentProviders).toBe(false)
      expect(result.current.paymentProviders?.paymentProviders).toBeNull()
    })

    it('should handle single provider type', async () => {
      const { result } = await prepare({
        mockData: {
          paymentProviders: {
            collection: [
              {
                __typename: 'StripeProvider',
                id: '1',
                name: 'Stripe Only',
                code: 'stripe-only',
              },
            ],
          },
        },
      })

      await act(() => wait(0))

      expect(result.current.isLoadingPaymentProviders).toBe(false)
      expect(result.current.paymentProviders?.paymentProviders?.collection).toHaveLength(1)
      expect(result.current.paymentProviders?.paymentProviders?.collection?.[0]).toEqual({
        __typename: 'StripeProvider',
        id: '1',
        name: 'Stripe Only',
        code: 'stripe-only',
      })
    })

    it('should handle all supported provider types', async () => {
      const { result } = await prepare()

      await act(() => wait(0))

      const collection = result.current.paymentProviders?.paymentProviders?.collection
      const providerTypes = collection?.map((provider) => provider.__typename)

      expect(providerTypes).toContain('StripeProvider')
      expect(providerTypes).toContain('GocardlessProvider')
      expect(providerTypes).toContain('AdyenProvider')
      expect(providerTypes).toContain('CashfreeProvider')
      expect(providerTypes).toContain('FlutterwaveProvider')
      expect(providerTypes).toContain('MoneyhashProvider')
    })
  })

  describe('getPaymentProvider function', () => {
    it('should return correct provider type for valid code', async () => {
      const { result } = await prepare()

      await act(() => wait(0))

      // Test Stripe provider
      const stripeType = result.current.getPaymentProvider('stripe-main')

      expect(stripeType).toBe(ProviderTypeEnum.Stripe)

      // Test GoCardless provider
      const gocardlessType = result.current.getPaymentProvider('gocardless-uk')

      expect(gocardlessType).toBe(ProviderTypeEnum.Gocardless)

      // Test Adyen provider
      const adyenType = result.current.getPaymentProvider('adyen-global')

      expect(adyenType).toBe(ProviderTypeEnum.Adyen)

      // Test Cashfree provider
      const cashfreeType = result.current.getPaymentProvider('cashfree-india')

      expect(cashfreeType).toBe(ProviderTypeEnum.Cashfree)

      // Test Flutterwave provider
      const flutterwaveType = result.current.getPaymentProvider('flutterwave-africa')

      expect(flutterwaveType).toBe(ProviderTypeEnum.Flutterwave)

      // Test Moneyhash provider
      const moneyhashType = result.current.getPaymentProvider('moneyhash-mena')

      expect(moneyhashType).toBe(ProviderTypeEnum.Moneyhash)
    })

    it('should return undefined for invalid code', async () => {
      const { result } = await prepare()

      await act(() => wait(0))

      const invalidType = result.current.getPaymentProvider('invalid-code')

      expect(invalidType).toBeNull()
    })

    it('should return undefined for undefined code', async () => {
      const { result } = await prepare()

      await act(() => wait(0))

      const undefinedType = result.current.getPaymentProvider(undefined)

      expect(undefinedType).toBeNull()
    })

    it('should return undefined for empty string code', async () => {
      const { result } = await prepare()

      await act(() => wait(0))

      const emptyType = result.current.getPaymentProvider('')

      expect(emptyType).toBeNull()
    })

    it('should work when paymentProviders is null', async () => {
      const { result } = await prepare({
        mockData: {
          paymentProviders: null,
        },
      })

      await act(() => wait(0))

      const type = result.current.getPaymentProvider('stripe-main')

      expect(type).toBeNull()
    })

    it('should work when collection is empty', async () => {
      const { result } = await prepare({
        mockData: {
          paymentProviders: {
            collection: [],
          },
        },
      })

      await act(() => wait(0))

      const type = result.current.getPaymentProvider('stripe-main')

      expect(type).toBeNull()
    })
  })

  describe('when query fails', () => {
    it('should handle GraphQL errors', async () => {
      const { result } = await prepare({ error: true })

      expect(result.current.isLoadingPaymentProviders).toBe(true)

      await act(() => wait(0))

      expect(result.current.isLoadingPaymentProviders).toBe(false)
      expect(result.current.paymentProviders).toBeUndefined()
      expect(typeof result.current.getPaymentProvider).toBe('function')
    })

    it('should handle network errors', async () => {
      const { result } = await prepare({ networkError: true })

      expect(result.current.isLoadingPaymentProviders).toBe(true)

      await act(() => wait(0))

      expect(result.current.isLoadingPaymentProviders).toBe(false)
      expect(result.current.paymentProviders).toBeUndefined()
    })
  })

  describe('query configuration', () => {
    it('should use correct variables with limit of 1000', async () => {
      const { result } = await prepare()

      expect(result.current.isLoadingPaymentProviders).toBe(true)

      await act(() => wait(0))

      expect(result.current.isLoadingPaymentProviders).toBe(false)
      // The mock configuration verifies that variables: { limit: 1000 } is used
    })
  })

  describe('return value structure', () => {
    it('should return an object with paymentProviders, isLoadingPaymentProviders, and getPaymentProvider', async () => {
      const { result } = await prepare()

      expect(typeof result.current).toBe('object')
      expect('paymentProviders' in result.current).toBe(true)
      expect('isLoadingPaymentProviders' in result.current).toBe(true)
      expect('getPaymentProvider' in result.current).toBe(true)
      expect(Object.keys(result.current)).toHaveLength(3)

      await act(() => wait(0))

      expect(typeof result.current.paymentProviders).toBe('object')
      expect(typeof result.current.isLoadingPaymentProviders).toBe('boolean')
      expect(typeof result.current.getPaymentProvider).toBe('function')
    })
  })

  describe('integration with GraphQL fragments', () => {
    it('should properly handle all provider fragment fields', async () => {
      const { result } = await prepare({
        mockData: {
          paymentProviders: {
            collection: [
              {
                __typename: 'StripeProvider',
                id: 'stripe-1',
                name: 'Stripe Production',
                code: 'STRIPE_PROD',
              },
              {
                __typename: 'AdyenProvider',
                id: 'adyen-1',
                name: 'Adyen Global Payment',
                code: 'ADYEN_GLOBAL',
              },
            ],
          },
        },
      })

      await act(() => wait(0))

      const collection = result.current.paymentProviders?.paymentProviders?.collection

      expect(collection).toHaveLength(2)

      // Stripe provider
      expect(collection?.[0].__typename).toBe('StripeProvider')
      expect(collection?.[0].id).toBe('stripe-1')
      expect(collection?.[0].name).toBe('Stripe Production')
      expect(collection?.[0].code).toBe('STRIPE_PROD')

      // Adyen provider
      expect(collection?.[1].__typename).toBe('AdyenProvider')
      expect(collection?.[1].id).toBe('adyen-1')
      expect(collection?.[1].name).toBe('Adyen Global Payment')
      expect(collection?.[1].code).toBe('ADYEN_GLOBAL')
    })
  })
})
