import { renderHook } from '@testing-library/react'

import { useGetOrderFormDetailsQuery } from '~/generated/graphql'

import { useOrderFormDetails } from '../useOrderFormDetails'

jest.mock('~/generated/graphql', () => ({
  useGetOrderFormDetailsQuery: jest.fn(),
}))

const mockUseGetOrderFormDetailsQuery = useGetOrderFormDetailsQuery as jest.Mock

describe('useOrderFormDetails', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN a valid order form id', () => {
    describe('WHEN the query returns data', () => {
      it('THEN should return the order form', () => {
        const mockOrderForm = { id: 'of-1', number: 'OF-2026-0001' }

        mockUseGetOrderFormDetailsQuery.mockReturnValue({
          data: { orderForm: mockOrderForm },
          loading: false,
          error: undefined,
        })

        const { result } = renderHook(() => useOrderFormDetails('of-1'))

        expect(result.current.orderForm).toEqual(mockOrderForm)
        expect(result.current.loading).toBe(false)
        expect(result.current.error).toBeUndefined()
      })

      it('THEN should pass the id as variable and not skip', () => {
        mockUseGetOrderFormDetailsQuery.mockReturnValue({
          data: { orderForm: null },
          loading: false,
          error: undefined,
        })

        renderHook(() => useOrderFormDetails('of-1'))

        expect(mockUseGetOrderFormDetailsQuery).toHaveBeenCalledWith(
          expect.objectContaining({
            variables: { id: 'of-1' },
            skip: false,
          }),
        )
      })
    })

    describe('WHEN the query is loading', () => {
      it('THEN should return loading true and an undefined order form', () => {
        mockUseGetOrderFormDetailsQuery.mockReturnValue({
          data: undefined,
          loading: true,
          error: undefined,
        })

        const { result } = renderHook(() => useOrderFormDetails('of-1'))

        expect(result.current.loading).toBe(true)
        expect(result.current.orderForm).toBeUndefined()
      })
    })

    describe('WHEN the query errors', () => {
      it('THEN should return the error', () => {
        const error = new Error('boom')

        mockUseGetOrderFormDetailsQuery.mockReturnValue({
          data: undefined,
          loading: false,
          error,
        })

        const { result } = renderHook(() => useOrderFormDetails('of-1'))

        expect(result.current.error).toBe(error)
        expect(result.current.orderForm).toBeUndefined()
      })
    })
  })

  describe('GIVEN no order form id', () => {
    it('THEN should skip the query', () => {
      mockUseGetOrderFormDetailsQuery.mockReturnValue({
        data: undefined,
        loading: false,
        error: undefined,
      })

      renderHook(() => useOrderFormDetails(undefined))

      expect(mockUseGetOrderFormDetailsQuery).toHaveBeenCalledWith(
        expect.objectContaining({ skip: true }),
      )
    })

    it('THEN should pass an empty id variable', () => {
      mockUseGetOrderFormDetailsQuery.mockReturnValue({
        data: undefined,
        loading: false,
        error: undefined,
      })

      renderHook(() => useOrderFormDetails(undefined))

      expect(mockUseGetOrderFormDetailsQuery).toHaveBeenCalledWith(
        expect.objectContaining({ variables: { id: '' } }),
      )
    })
  })
})
