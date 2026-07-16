import { renderHook } from '@testing-library/react'

import { useGetQuotesQuery } from '~/generated/graphql'

import { useQuotes } from '../useQuotes'

jest.mock('~/generated/graphql', () => ({
  useGetQuotesQuery: jest.fn(),
}))

const mockUseGetQuotesQuery = useGetQuotesQuery as jest.Mock

describe('useQuotes', () => {
  const mockFetchMore = jest.fn()

  beforeEach(() => {
    jest.clearAllMocks()
    mockUseGetQuotesQuery.mockReturnValue({
      data: undefined,
      loading: false,
      error: undefined,
      fetchMore: mockFetchMore,
    })
  })

  describe('GIVEN the hook is rendered', () => {
    it('THEN should pass limit of 20 as default', () => {
      renderHook(() => useQuotes())

      expect(mockUseGetQuotesQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: expect.objectContaining({ limit: 20 }),
        }),
      )
    })
  })

  describe('GIVEN custom variables are provided', () => {
    it('THEN should merge them with defaults', () => {
      renderHook(() => useQuotes({ numbers: ['QT-001'] }))

      expect(mockUseGetQuotesQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: expect.objectContaining({
            limit: 20,
            numbers: ['QT-001'],
          }),
        }),
      )
    })
  })

  describe('GIVEN the query returns data', () => {
    it('THEN should return the quotes collection', () => {
      const mockQuotes = [
        { id: 'q1', number: 'QT-001' },
        { id: 'q2', number: 'QT-002' },
      ]

      mockUseGetQuotesQuery.mockReturnValue({
        data: {
          quotes: {
            collection: mockQuotes,
            metadata: { currentPage: 1, totalPages: 2, totalCount: 10 },
          },
        },
        loading: false,
        error: undefined,
        fetchMore: mockFetchMore,
      })

      const { result } = renderHook(() => useQuotes())

      expect(result.current.quotes).toEqual(mockQuotes)
      expect(result.current.metadata).toEqual({
        currentPage: 1,
        totalPages: 2,
        totalCount: 10,
      })
    })
  })

  describe('GIVEN the query has no data yet', () => {
    it('THEN should return an empty array for quotes', () => {
      const { result } = renderHook(() => useQuotes())

      expect(result.current.quotes).toEqual([])
      expect(result.current.metadata).toBeUndefined()
    })
  })

  describe('GIVEN the query is loading', () => {
    it('THEN should return loading true', () => {
      mockUseGetQuotesQuery.mockReturnValue({
        data: undefined,
        loading: true,
        error: undefined,
        fetchMore: mockFetchMore,
      })

      const { result } = renderHook(() => useQuotes())

      expect(result.current.loading).toBe(true)
    })
  })
})
