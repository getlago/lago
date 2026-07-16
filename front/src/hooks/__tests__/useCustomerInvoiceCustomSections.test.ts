import { wait } from '@apollo/client/testing'
import { act, renderHook } from '@testing-library/react'
import React from 'react'

import { GetCustomerInvoiceCustomSectionsDocument } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { useCustomerInvoiceCustomSections } from '../useCustomerInvoiceCustomSections'

const CUSTOMER_ID = 'customer-123'

const mockCustomerResponse = {
  customer: {
    __typename: 'Customer',
    id: CUSTOMER_ID,
    externalId: 'ext-customer-123',
    hasOverwrittenInvoiceCustomSectionsSelection: true,
    skipInvoiceCustomSections: false,
    configurableInvoiceCustomSections: [
      {
        __typename: 'InvoiceCustomSection',
        id: 'section-1',
        name: 'Section 1',
      },
      {
        __typename: 'InvoiceCustomSection',
        id: 'section-2',
        name: 'Section 2',
      },
    ],
  },
}

type PrepareType = {
  customerId?: string
  mock?: Record<string, unknown>
  error?: boolean
  delay?: number
  skipQuery?: boolean
}

async function prepare({
  customerId,
  mock,
  error = false,
  delay = 0,
  skipQuery = false,
}: PrepareType = {}) {
  const actualCustomerId = customerId ?? CUSTOMER_ID
  const mocks = skipQuery
    ? []
    : [
        {
          request: {
            query: GetCustomerInvoiceCustomSectionsDocument,
            variables: { customerId: actualCustomerId },
          },
          result: error
            ? {
                errors: [{ message: 'Network error' }],
              }
            : {
                data: mock || mockCustomerResponse,
                delay,
              },
        },
      ]

  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({
      children,
      mocks,
      forceTypenames: true,
    })

  const hookCustomerId = skipQuery ? undefined : actualCustomerId
  const { result } = renderHook(() => useCustomerInvoiceCustomSections(hookCustomerId), {
    wrapper: customWrapper,
  })

  return { result }
}

describe('useCustomerInvoiceCustomSections', () => {
  describe('WHEN query succeeds with complete data', () => {
    it('THEN returns correctly transformed customer invoice custom sections data', async () => {
      const { result } = await prepare()

      await act(() => wait(0))

      expect(result.current.loading).toBe(false)
      expect(result.current.error).toBe(false)
      expect(result.current.data).toEqual({
        configurableInvoiceCustomSections: [
          { id: 'section-1', name: 'Section 1' },
          { id: 'section-2', name: 'Section 2' },
        ],
        hasOverwrittenInvoiceCustomSectionsSelection: true,
        skipInvoiceCustomSections: false,
      })
      expect(result.current.customer).toEqual(mockCustomerResponse.customer)
    })
  })

  describe('WHEN customerId is undefined', () => {
    it('THEN skips the query and returns null data', async () => {
      const { result } = await prepare({ skipQuery: true })

      await act(() => wait(0))

      expect(result.current.loading).toBe(false)
      expect(result.current.error).toBe(false)
      expect(result.current.data).toBe(null)
      expect(result.current.customer).toBe(null)
    })
  })

  describe('WHEN query fails', () => {
    it('THEN returns error state and null data', async () => {
      const { result } = await prepare({ error: true })

      await act(() => wait(0))

      expect(result.current.loading).toBe(false)
      expect(result.current.error).toBe(true)
      expect(result.current.data).toBe(null)
      expect(result.current.customer).toBe(null)
    })
  })
})
