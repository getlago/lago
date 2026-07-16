import { TranslateFunc } from '~/hooks/core/useInternationalization'

import { formatCountToMetadata } from '../formatCountToMetadata'

describe('formatCountToMetadata', () => {
  const mockTranslate = jest.fn(
    (key: string, params?: Record<string, string | number>, count?: number) =>
      count === 1 ? `${params?.count} result` : `${params?.count} results`,
  ) as unknown as TranslateFunc

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN count is undefined', () => {
    describe('WHEN called', () => {
      it('THEN should return undefined', () => {
        const result = formatCountToMetadata(undefined, mockTranslate)

        expect(result).toBeUndefined()
        expect(mockTranslate).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN count is null', () => {
    describe('WHEN called', () => {
      it('THEN should return undefined', () => {
        const result = formatCountToMetadata(null, mockTranslate)

        expect(result).toBeUndefined()
        expect(mockTranslate).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN count is 0', () => {
    describe('WHEN called', () => {
      it('THEN should call translate with count 0', () => {
        const result = formatCountToMetadata(0, mockTranslate)

        expect(mockTranslate).toHaveBeenCalledWith(expect.any(String), { count: 0 }, 0)
        expect(result).toBe('0 results')
      })
    })
  })

  describe('GIVEN count is 1', () => {
    describe('WHEN called', () => {
      it('THEN should call translate with count 1 for singular', () => {
        const result = formatCountToMetadata(1, mockTranslate)

        expect(mockTranslate).toHaveBeenCalledWith(expect.any(String), { count: 1 }, 1)
        expect(result).toBe('1 result')
      })
    })
  })

  describe('GIVEN count is a positive number', () => {
    describe('WHEN called', () => {
      it('THEN should call translate with the count value', () => {
        const result = formatCountToMetadata(42, mockTranslate)

        expect(mockTranslate).toHaveBeenCalledWith(expect.any(String), { count: 42 }, 42)
        expect(result).toBe('42 results')
      })
    })
  })

  describe('GIVEN count is a large number', () => {
    describe('WHEN called', () => {
      it('THEN should pass the raw count for pluralization', () => {
        const result = formatCountToMetadata(1234, mockTranslate)

        expect(mockTranslate).toHaveBeenCalledWith(expect.any(String), { count: 1234 }, 1234)
        expect(result).toBe('1234 results')
      })
    })
  })
})
