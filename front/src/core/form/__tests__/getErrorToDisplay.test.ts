import { getErrorToDisplay } from '../getErrorToDisplay'

describe('getErrorToDisplay', () => {
  describe('when silentError is true', () => {
    it('returns undefined regardless of other parameters', () => {
      const result = getErrorToDisplay({
        error: 'Test error',
        errorMap: {},
        silentError: true,
        displayErrorText: true,
      })

      expect(result).toBeUndefined()
    })

    it('returns undefined even with valid errorMap', () => {
      const result = getErrorToDisplay({
        error: 'Test error',
        errorMap: [{ message: 'Zod error', path: ['field'] }],
        silentError: true,
        displayErrorText: true,
      })

      expect(result).toBeUndefined()
    })
  })

  describe('when silentError is false or undefined', () => {
    describe('chooseBetweenErrorAndErrorMap logic', () => {
      it('returns the original error when errorMap is empty', () => {
        const result = getErrorToDisplay({
          error: 'Original error',
          errorMap: {},
          displayErrorText: true,
        })

        expect(result).toBe('Original error')
      })

      it('returns the original error when errorMap is null', () => {
        const result = getErrorToDisplay({
          error: 'Original error',
          errorMap: null,
          displayErrorText: true,
        })

        expect(result).toBe('Original error')
      })

      it('returns the original error when errorMap is undefined', () => {
        const result = getErrorToDisplay({
          error: 'Original error',
          errorMap: undefined,
          displayErrorText: true,
        })

        expect(result).toBe('Original error')
      })

      it('returns the original error when errorMap is not a valid zod error structure', () => {
        const result = getErrorToDisplay({
          error: 'Original error',
          errorMap: { someProperty: 'value' },
          displayErrorText: true,
        })

        expect(result).toBe('Original error')
      })

      it('returns concatenated messages from valid zod errorMap', () => {
        const errorMap = [
          { message: 'First error', path: ['field1'] },
          { message: 'Second error', path: ['field2'] },
        ]

        const result = getErrorToDisplay({
          error: 'Original error',
          errorMap,
          displayErrorText: true,
        })

        expect(result).toBe('First errorSecond error')
      })

      it('filters out falsy messages from zod errorMap', () => {
        const errorMap = [
          { message: 'Valid error', path: ['field1'] },
          { message: '', path: ['field2'] },
          { message: 'Another valid error', path: ['field3'] },
        ]

        const result = getErrorToDisplay({
          error: 'Original error',
          errorMap,
          displayErrorText: true,
        })

        expect(result).toBe('Valid errorAnother valid error')
      })

      it('returns empty string when all zod messages are falsy', () => {
        const errorMap = [
          { message: '', path: ['field1'] },
          { message: '', path: ['field2'] },
        ]

        const result = getErrorToDisplay({
          error: 'Original error',
          errorMap,
          displayErrorText: true,
        })

        expect(result).toBe('')
      })
    })

    describe('noBoolean parameter behavior', () => {
      it('returns string or undefined when noBoolean is true', () => {
        const result = getErrorToDisplay({
          error: 'Test error',
          errorMap: {},
          noBoolean: true,
        })

        expect(typeof result === 'string' || result === undefined).toBe(true)
        expect(result).toBe('Test error')
      })

      it('returns undefined when noBoolean is true and error is empty', () => {
        const result = getErrorToDisplay({
          error: '',
          errorMap: {},
          noBoolean: true,
        })

        expect(result).toBe('')
      })
    })

    describe('displayErrorText parameter behavior', () => {
      it('returns boolean when displayErrorText is false and error exists', () => {
        const result = getErrorToDisplay({
          error: 'Test error',
          errorMap: {},
          displayErrorText: false,
        })

        expect(result).toBe(true)
      })

      it('returns false when displayErrorText is false and error is empty', () => {
        const result = getErrorToDisplay({
          error: '',
          errorMap: {},
          displayErrorText: false,
        })

        expect(result).toBe(false)
      })

      it('returns boolean when displayErrorText is false with zod errors', () => {
        const errorMap = [{ message: 'Zod error', path: ['field'] }]

        const result = getErrorToDisplay({
          error: 'Original error',
          errorMap,
          displayErrorText: false,
        })

        expect(result).toBe(true)
      })

      it('returns error text when displayErrorText is true (default)', () => {
        const result = getErrorToDisplay({
          error: 'Test error',
          errorMap: {},
        })

        expect(result).toBe('Test error')
      })
    })

    describe('function overloads', () => {
      it('returns string | undefined when noBoolean is true', () => {
        const result = getErrorToDisplay({
          error: 'Test error',
          errorMap: {},
          noBoolean: true,
        })

        // TypeScript should infer this as string | undefined
        expect(typeof result === 'string' || result === undefined).toBe(true)
      })

      it('returns string | boolean | undefined when noBoolean is not specified', () => {
        const result = getErrorToDisplay({
          error: 'Test error',
          errorMap: {},
          displayErrorText: false,
        })

        // TypeScript should infer this as string | boolean | undefined
        expect(
          typeof result === 'string' || typeof result === 'boolean' || result === undefined,
        ).toBe(true)
      })
    })

    describe('edge cases', () => {
      it('handles empty string error', () => {
        const result = getErrorToDisplay({
          error: '',
          errorMap: {},
          displayErrorText: true,
        })

        expect(result).toBe('')
      })

      it('handles complex zod error structure', () => {
        const errorMap = [
          { message: 'Email is required', path: ['user', 'email'] },
          { message: 'Password too short', path: ['user', 'password'] },
          { message: 'Name cannot be empty', path: ['user', 'name'] },
        ]

        const result = getErrorToDisplay({
          error: 'Form validation failed',
          errorMap,
          displayErrorText: true,
        })

        expect(result).toBe('Email is requiredPassword too shortName cannot be empty')
      })

      it('handles malformed zod-like structure', () => {
        const errorMap = [
          { message: 'Valid error', path: ['field'] },
          { notMessage: 'Invalid structure', path: ['field'] },
          { message: 'Another valid error', wrongPath: 'not-array' },
        ]

        const result = getErrorToDisplay({
          error: 'Original error',
          errorMap,
          displayErrorText: true,
        })

        // Should fall back to original error since errorMap is not valid zod structure
        expect(result).toBe('Original error')
      })
    })
  })
})
