import { renderHook } from '@testing-library/react'

import { useGetQuoteQuery } from '~/generated/graphql'

import { useQuote } from '../useQuote'

jest.mock('~/generated/graphql', () => ({
  useGetQuoteQuery: jest.fn(),
}))

const mockUseGetQuoteQuery = useGetQuoteQuery as jest.Mock

describe('useQuote', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN a valid quote id', () => {
    describe('WHEN the query returns data', () => {
      it('THEN should return the quote', () => {
        const mockQuote = { id: 'quote-1', number: 'QT-001' }

        mockUseGetQuoteQuery.mockReturnValue({
          data: { quote: mockQuote },
          loading: false,
          error: undefined,
        })

        const { result } = renderHook(() => useQuote('quote-1'))

        expect(result.current.quote).toEqual(mockQuote)
        expect(result.current.loading).toBe(false)
        expect(result.current.error).toBeUndefined()
      })

      it('THEN should pass the id as variable and not skip', () => {
        mockUseGetQuoteQuery.mockReturnValue({
          data: { quote: null },
          loading: false,
          error: undefined,
        })

        renderHook(() => useQuote('quote-1'))

        expect(mockUseGetQuoteQuery).toHaveBeenCalledWith(
          expect.objectContaining({
            variables: { id: 'quote-1' },
            skip: false,
          }),
        )
      })
    })

    describe('WHEN the query is loading', () => {
      it('THEN should return loading true', () => {
        mockUseGetQuoteQuery.mockReturnValue({
          data: undefined,
          loading: true,
          error: undefined,
        })

        const { result } = renderHook(() => useQuote('quote-1'))

        expect(result.current.loading).toBe(true)
        expect(result.current.quote).toBeUndefined()
      })
    })
  })

  describe('GIVEN no quote id', () => {
    it('THEN should skip the query', () => {
      mockUseGetQuoteQuery.mockReturnValue({
        data: undefined,
        loading: false,
        error: undefined,
      })

      renderHook(() => useQuote(undefined))

      expect(mockUseGetQuoteQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: true,
        }),
      )
    })

    it('THEN should return undefined quote', () => {
      mockUseGetQuoteQuery.mockReturnValue({
        data: undefined,
        loading: false,
        error: undefined,
      })

      const { result } = renderHook(() => useQuote(undefined))

      expect(result.current.quote).toBeUndefined()
    })
  })
})
