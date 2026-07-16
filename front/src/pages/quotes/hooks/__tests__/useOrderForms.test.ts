import { renderHook } from '@testing-library/react'

import { useGetOrderFormsQuery } from '~/generated/graphql'

import { useOrderForms } from '../useOrderForms'

jest.mock('~/generated/graphql', () => ({
  useGetOrderFormsQuery: jest.fn(),
}))

const mockUseGetOrderFormsQuery = useGetOrderFormsQuery as jest.Mock

describe('useOrderForms', () => {
  const mockFetchMore = jest.fn()

  beforeEach(() => {
    jest.clearAllMocks()
    mockUseGetOrderFormsQuery.mockReturnValue({
      data: undefined,
      loading: false,
      error: undefined,
      fetchMore: mockFetchMore,
    })
  })

  describe('GIVEN the hook is rendered', () => {
    it('THEN should pass limit of 20 as default', () => {
      renderHook(() => useOrderForms())

      expect(mockUseGetOrderFormsQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: expect.objectContaining({ limit: 20 }),
        }),
      )
    })
  })

  describe('GIVEN custom variables are provided', () => {
    it('THEN should merge them with defaults', () => {
      renderHook(() => useOrderForms({ status: ['generated' as never] }))

      expect(mockUseGetOrderFormsQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: expect.objectContaining({
            limit: 20,
            status: ['generated'],
          }),
        }),
      )
    })
  })

  describe('GIVEN the query returns data', () => {
    it('THEN should return the order forms collection', () => {
      const mockOrderForms = [
        { id: 'of-1', number: 'OF-001' },
        { id: 'of-2', number: 'OF-002' },
      ]

      mockUseGetOrderFormsQuery.mockReturnValue({
        data: {
          orderForms: {
            collection: mockOrderForms,
            metadata: { currentPage: 1, totalPages: 2, totalCount: 10 },
          },
        },
        loading: false,
        error: undefined,
        fetchMore: mockFetchMore,
      })

      const { result } = renderHook(() => useOrderForms())

      expect(result.current.orderForms).toEqual(mockOrderForms)
      expect(result.current.metadata).toEqual({
        currentPage: 1,
        totalPages: 2,
        totalCount: 10,
      })
    })
  })

  describe('GIVEN the query has no data yet', () => {
    it('THEN should return an empty array for order forms', () => {
      const { result } = renderHook(() => useOrderForms())

      expect(result.current.orderForms).toEqual([])
      expect(result.current.metadata).toBeUndefined()
    })
  })

  describe('GIVEN the query is loading', () => {
    it('THEN should return loading true', () => {
      mockUseGetOrderFormsQuery.mockReturnValue({
        data: undefined,
        loading: true,
        error: undefined,
        fetchMore: mockFetchMore,
      })

      const { result } = renderHook(() => useOrderForms())

      expect(result.current.loading).toBe(true)
    })
  })
})
