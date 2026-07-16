import { wait } from '@apollo/client/testing'
import { act, renderHook } from '@testing-library/react'
import React from 'react'

import { GetCustomerOverdueInvoicesReadyForPaymentProcessingDocument } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { useIsCustomerReadyForOverduePayment } from '../useIsCustomerReadyForOverduePayment'

const CUSTOMER_ID = 'customer-123'

type PrepareType = {
  mock?: {
    invoices?: {
      collection?: Array<{ readyForPaymentProcessing: boolean }>
    }
  }
  delay?: number
}

async function prepare({ mock, delay = 0 }: PrepareType = {}) {
  const mocks = [
    {
      request: {
        query: GetCustomerOverdueInvoicesReadyForPaymentProcessingDocument,
        variables: { id: CUSTOMER_ID },
      },
      result: {
        data: mock || {
          invoices: {
            collection: [{ readyForPaymentProcessing: true }, { readyForPaymentProcessing: true }],
          },
        },
        delay,
      },
    },
  ]

  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({
      children,
      mocks,
      forceTypenames: true,
      useParams: { customerId: CUSTOMER_ID },
    })

  const { result } = renderHook(() => useIsCustomerReadyForOverduePayment(), {
    wrapper: customWrapper,
  })

  return { result }
}

describe('useIsCustomerReadyForOverduePayment', () => {
  describe('WHEN all invoices are ready for payment processing', () => {
    it('THEN returns data as true', async () => {
      const { result } = await prepare({
        mock: {
          invoices: {
            collection: [{ readyForPaymentProcessing: true }, { readyForPaymentProcessing: true }],
          },
        },
      })

      // Wait for the mock query to complete
      await act(() => wait(0))

      expect(result.current.isCustomerReadyForOverduePayment).toBe(true)
    })
  })

  describe('WHEN at least one invoice is not ready for payment processing', () => {
    it('THEN returns data as false', async () => {
      const { result } = await prepare({
        mock: {
          invoices: {
            collection: [{ readyForPaymentProcessing: true }, { readyForPaymentProcessing: false }],
          },
        },
      })

      // Wait for the mock query to complete
      await act(() => wait(0))

      expect(result.current.isCustomerReadyForOverduePayment).toBe(false)
    })
  })

  describe('WHEN query is loading', () => {
    it('THEN returns loading as true and isCustomerReadyForOverduePayment as false', async () => {
      const { result } = await prepare({ delay: 100 })

      expect(result.current.loading).toBeTruthy()
      expect(result.current.isCustomerReadyForOverduePayment).toBe(false)
    })
  })
})
