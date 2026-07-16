import { wait } from '@apollo/client/testing'
import { act, renderHook } from '@testing-library/react'
import React from 'react'

import { PaymentMethodsDocument } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { createMockPaymentMethodsQueryResponse } from './factories/PaymentMethod.factory'

import { usePaymentMethodsList } from '../usePaymentMethodsList'

const EXTERNAL_CUSTOMER_ID = 'customer_ext_123'

const mockPaymentMethodsQueryResponse = createMockPaymentMethodsQueryResponse()

type PrepareType = {
  mock?: Record<string, unknown>
  error?: boolean
  delay?: number
  withDeleted?: boolean
}

async function prepare({ mock, error = false, delay = 0, withDeleted }: PrepareType = {}) {
  const variables: { externalCustomerId: string; withDeleted?: boolean } = {
    externalCustomerId: EXTERNAL_CUSTOMER_ID,
  }

  if (withDeleted !== undefined) {
    variables.withDeleted = withDeleted
  } else {
    variables.withDeleted = true
  }

  const mocks = [
    {
      request: {
        query: PaymentMethodsDocument,
        variables,
      },
      result: error
        ? {
            errors: [{ message: 'Network error' }],
          }
        : {
            data: mock || mockPaymentMethodsQueryResponse,
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

  const hookArgs: { externalCustomerId: string; withDeleted?: boolean } = {
    externalCustomerId: EXTERNAL_CUSTOMER_ID,
  }

  if (withDeleted !== undefined) {
    hookArgs.withDeleted = withDeleted
  }

  const { result } = renderHook(() => usePaymentMethodsList(hookArgs), {
    wrapper: customWrapper,
  })

  return { result }
}

describe('usePaymentMethodsList', () => {
  describe('WHEN query succeeds with data', () => {
    it('THEN returns payment methods list', async () => {
      const { result } = await prepare()

      expect(result.current.loading).toBeTruthy()

      await act(() => wait(0))

      expect(result.current.loading).toBeFalsy()
      expect(result.current.error).toBeFalsy()
      expect(result.current.data).toHaveLength(2)
      expect(result.current.data[0].id).toBe('pm_001')
      expect(result.current.data[0].isDefault).toBe(true)
      expect(result.current.data[1].id).toBe('pm_002')
      expect(result.current.data[1].isDefault).toBe(false)
      expect(result.current.refetch).toBeDefined()
    })

    it('THEN returns empty array when data is null', async () => {
      const { result } = await prepare({
        mock: {
          paymentMethods: null,
        },
      })

      expect(result.current.loading).toBeTruthy()

      await act(() => wait(0))

      expect(result.current.loading).toBeFalsy()
      expect(result.current.error).toBeFalsy()
      expect(result.current.data).toEqual([])
    })
  })

  describe('WHEN query fails', () => {
    it('THEN returns error state', async () => {
      const { result } = await prepare({ error: true })

      expect(result.current.loading).toBeTruthy()

      await act(() => wait(0))

      expect(result.current.loading).toBeFalsy()
      expect(result.current.error).toBeTruthy()
      expect(result.current.data).toEqual([])
    })
  })

  describe('WHEN externalCustomerId is undefined or empty', () => {
    it('THEN skips the query and returns empty data', async () => {
      const customWrapper = ({ children }: { children: React.ReactNode }) =>
        AllTheProviders({
          children,
          mocks: [],
          forceTypenames: true,
        })

      const { result } = renderHook(() => usePaymentMethodsList({}), {
        wrapper: customWrapper,
      })

      // Query should be skipped, so no loading state
      expect(result.current.loading).toBeFalsy()
      expect(result.current.error).toBeFalsy()
      expect(result.current.data).toEqual([])
    })

    it('THEN skips the query when externalCustomerId is empty string', async () => {
      const customWrapper = ({ children }: { children: React.ReactNode }) =>
        AllTheProviders({
          children,
          mocks: [],
          forceTypenames: true,
        })

      const { result } = renderHook(() => usePaymentMethodsList({ externalCustomerId: '' }), {
        wrapper: customWrapper,
      })

      expect(result.current.loading).toBeFalsy()
      expect(result.current.error).toBeFalsy()
      expect(result.current.data).toEqual([])
    })
  })

  describe('WHEN withDeleted parameter is used', () => {
    it('THEN uses withDeleted=true as default', async () => {
      const { result } = await prepare()

      expect(result.current.loading).toBeTruthy()

      await act(() => wait(0))

      expect(result.current.loading).toBeFalsy()
      expect(result.current.error).toBeFalsy()
      expect(result.current.data).toHaveLength(2)
    })

    it('THEN works with withDeleted=true explicitly', async () => {
      const { result } = await prepare({ withDeleted: true })

      expect(result.current.loading).toBeTruthy()

      await act(() => wait(0))

      expect(result.current.loading).toBeFalsy()
      expect(result.current.error).toBeFalsy()
      expect(result.current.data).toHaveLength(2)
    })

    it('THEN works with withDeleted=false', async () => {
      const { result } = await prepare({ withDeleted: false })

      expect(result.current.loading).toBeTruthy()

      await act(() => wait(0))

      expect(result.current.loading).toBeFalsy()
      expect(result.current.error).toBeFalsy()
      expect(result.current.data).toHaveLength(2)
    })
  })
})
