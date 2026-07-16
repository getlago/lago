import { renderHook } from '@testing-library/react'

import { useGetOrdersQuery } from '~/generated/graphql'

import { useOrders } from '../useOrders'

jest.mock('~/generated/graphql', () => ({
  useGetOrdersQuery: jest.fn(),
}))

const mockUseGetOrdersQuery = useGetOrdersQuery as jest.Mock

describe('useOrders', () => {
  const mockFetchMore = jest.fn()

  beforeEach(() => {
    jest.clearAllMocks()
    mockUseGetOrdersQuery.mockReturnValue({
      data: undefined,
      loading: false,
      error: undefined,
      fetchMore: mockFetchMore,
    })
  })

  describe('GIVEN the hook is rendered', () => {
    it('THEN should pass limit of 20 as default', () => {
      renderHook(() => useOrders())

      expect(mockUseGetOrdersQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: expect.objectContaining({ limit: 20 }),
        }),
      )
    })
  })

  describe('GIVEN a quoteNumber is provided', () => {
    it('THEN should merge it with defaults', () => {
      renderHook(() => useOrders({ quoteNumber: ['QUO-001'] }))

      expect(mockUseGetOrdersQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: expect.objectContaining({
            limit: 20,
            quoteNumber: ['QUO-001'],
          }),
        }),
      )
    })
  })

  describe('GIVEN the query returns data', () => {
    it('THEN should return the orders collection', () => {
      const mockOrders = [
        { id: 'order-1', number: 'ORD-001' },
        { id: 'order-2', number: 'ORD-002' },
      ]

      mockUseGetOrdersQuery.mockReturnValue({
        data: {
          orders: {
            collection: mockOrders,
            metadata: { currentPage: 1, totalPages: 2, totalCount: 10 },
          },
        },
        loading: false,
        error: undefined,
        fetchMore: mockFetchMore,
      })

      const { result } = renderHook(() => useOrders())

      expect(result.current.orders).toEqual(mockOrders)
      expect(result.current.metadata).toEqual({
        currentPage: 1,
        totalPages: 2,
        totalCount: 10,
      })
    })
  })

  describe('GIVEN the query has no data yet', () => {
    it('THEN should return an empty array for orders', () => {
      const { result } = renderHook(() => useOrders())

      expect(result.current.orders).toEqual([])
      expect(result.current.metadata).toBeUndefined()
    })
  })

  describe('GIVEN the query is loading', () => {
    it('THEN should return loading true', () => {
      mockUseGetOrdersQuery.mockReturnValue({
        data: undefined,
        loading: true,
        error: undefined,
        fetchMore: mockFetchMore,
      })

      const { result } = renderHook(() => useOrders())

      expect(result.current.loading).toBe(true)
    })
  })
})
