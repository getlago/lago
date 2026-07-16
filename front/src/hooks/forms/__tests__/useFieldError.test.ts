import { renderHook } from '@testing-library/react'

import { useFieldError } from '../useFieldError'

// Mock dependencies
const mockTranslate = jest.fn((key: string) => `translated_${key}`)

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: mockTranslate,
  }),
}))

const mockUseStore = jest.fn()

jest.mock('@tanstack/react-form', () => ({
  useStore: (store: unknown, selector: (state: unknown) => unknown) =>
    mockUseStore(store, selector),
}))

const mockFieldStore = { id: 'test-field-store' }
const mockField = {
  store: mockFieldStore,
}

jest.mock('../formContext', () => ({
  useFieldContext: () => mockField,
}))

describe('useFieldError', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN no errors are present', () => {
    beforeEach(() => {
      mockUseStore.mockImplementation((_store, selector) => {
        const state = {
          meta: {
            errorMap: {},
            errors: [],
          },
        }

        return selector(state)
      })
    })

    describe('WHEN called with default options', () => {
      it('THEN should return empty string', () => {
        const { result } = renderHook(() => useFieldError())

        expect(result.current).toBe('')
      })
    })
  })

  describe('GIVEN errors are present', () => {
    beforeEach(() => {
      mockUseStore.mockImplementation((_store, selector) => {
        const state = {
          meta: {
            errorMap: {},
            errors: [{ message: 'error_key_1' }, { message: 'error_key_2' }],
          },
        }

        return selector(state)
      })
    })

    describe('WHEN called with default options', () => {
      it('THEN should return concatenated error messages', () => {
        const { result } = renderHook(() => useFieldError())

        expect(result.current).toBe('error_key_1error_key_2')
      })
    })

    describe('WHEN translateErrors is true', () => {
      it('THEN should translate and join errors with newline', () => {
        const { result } = renderHook(() => useFieldError({ translateErrors: true }))

        expect(mockTranslate).toHaveBeenCalledWith('error_key_1')
        expect(mockTranslate).toHaveBeenCalledWith('error_key_2')
        expect(result.current).toBe('translated_error_key_1\ntranslated_error_key_2')
      })
    })
  })

  describe('GIVEN silentError option', () => {
    beforeEach(() => {
      mockUseStore.mockImplementation((_store, selector) => {
        const state = {
          meta: {
            errorMap: {},
            errors: [{ message: 'error_key' }],
          },
        }

        return selector(state)
      })
    })

    describe('WHEN silentError is true', () => {
      it('THEN should return undefined', () => {
        const { result } = renderHook(() => useFieldError({ silentError: true }))

        expect(result.current).toBeUndefined()
      })
    })

    describe('WHEN silentError is false', () => {
      it('THEN should return the error', () => {
        const { result } = renderHook(() => useFieldError({ silentError: false }))

        expect(result.current).toBe('error_key')
      })
    })
  })

  describe('GIVEN displayErrorText option', () => {
    beforeEach(() => {
      mockUseStore.mockImplementation((_store, selector) => {
        const state = {
          meta: {
            errorMap: {},
            errors: [{ message: 'error_key' }],
          },
        }

        return selector(state)
      })
    })

    describe('WHEN displayErrorText is false', () => {
      it('THEN should return boolean true for existing error', () => {
        const { result } = renderHook(() => useFieldError({ displayErrorText: false }))

        expect(result.current).toBe(true)
      })
    })

    describe('WHEN displayErrorText is true', () => {
      it('THEN should return the error string', () => {
        const { result } = renderHook(() => useFieldError({ displayErrorText: true }))

        expect(result.current).toBe('error_key')
      })
    })
  })

  describe('GIVEN displayErrorText is false and no errors', () => {
    beforeEach(() => {
      mockUseStore.mockImplementation((_store, selector) => {
        const state = {
          meta: {
            errorMap: {},
            errors: [],
          },
        }

        return selector(state)
      })
    })

    describe('WHEN called', () => {
      it('THEN should return boolean false', () => {
        const { result } = renderHook(() => useFieldError({ displayErrorText: false }))

        expect(result.current).toBe(false)
      })
    })
  })

  describe('GIVEN showOnlyErrors option', () => {
    beforeEach(() => {
      mockUseStore.mockImplementation((_store, selector) => {
        const state = {
          meta: {
            errorMap: {},
            errors: [
              { message: 'error_to_show' },
              { message: 'error_to_hide' },
              { message: 'another_error_to_show' },
            ],
          },
        }

        return selector(state)
      })
    })

    describe('WHEN showOnlyErrors contains specific error keys', () => {
      it('THEN should only return matching errors', () => {
        const { result } = renderHook(() =>
          useFieldError({ showOnlyErrors: ['error_to_show', 'another_error_to_show'] }),
        )

        expect(result.current).toBe('error_to_showanother_error_to_show')
      })
    })

    describe('WHEN showOnlyErrors is empty array', () => {
      it('THEN should return empty string', () => {
        const { result } = renderHook(() => useFieldError({ showOnlyErrors: [] }))

        expect(result.current).toBe('')
      })
    })

    describe('WHEN showOnlyErrors contains non-matching keys', () => {
      it('THEN should return empty string', () => {
        const { result } = renderHook(() => useFieldError({ showOnlyErrors: ['non_existent'] }))

        expect(result.current).toBe('')
      })
    })
  })

  describe('GIVEN noBoolean option', () => {
    describe('WHEN noBoolean is true and errors exist', () => {
      beforeEach(() => {
        mockUseStore.mockImplementation((_store, selector) => {
          const state = {
            meta: {
              errorMap: {},
              errors: [{ message: 'error_key' }],
            },
          }

          return selector(state)
        })
      })

      it('THEN should return error string', () => {
        const { result } = renderHook(() => useFieldError({ noBoolean: true }))

        expect(result.current).toBe('error_key')
      })
    })

    describe('WHEN noBoolean is true and no errors exist', () => {
      beforeEach(() => {
        mockUseStore.mockImplementation((_store, selector) => {
          const state = {
            meta: {
              errorMap: {},
              errors: [],
            },
          }

          return selector(state)
        })
      })

      it('THEN should return empty string', () => {
        const { result } = renderHook(() => useFieldError({ noBoolean: true }))

        expect(result.current).toBe('')
      })
    })
  })

  describe('GIVEN firstOnly option', () => {
    beforeEach(() => {
      mockUseStore.mockImplementation((_store, selector) => {
        const state = {
          meta: {
            errorMap: {},
            errors: [
              { message: 'required_field' },
              { message: 'must_be_positive' },
              { message: 'exceeds_maximum' },
            ],
          },
        }

        return selector(state)
      })
    })

    describe('WHEN firstOnly is true', () => {
      it('THEN should return only the first error and exclude subsequent ones', () => {
        const { result } = renderHook(() => useFieldError({ firstOnly: true }))

        expect(result.current).toBe('required_field')
        expect(result.current).not.toContain('must_be_positive')
        expect(result.current).not.toContain('exceeds_maximum')
      })
    })

    describe('WHEN firstOnly is true with translateErrors', () => {
      it('THEN should translate only the first error', () => {
        const { result } = renderHook(() =>
          useFieldError({ firstOnly: true, translateErrors: true }),
        )

        expect(mockTranslate).toHaveBeenCalledWith('required_field')
        expect(mockTranslate).not.toHaveBeenCalledWith('must_be_positive')
        expect(mockTranslate).not.toHaveBeenCalledWith('exceeds_maximum')
        expect(result.current).toBe('translated_required_field')
      })
    })
  })

  describe('GIVEN errors with null or undefined messages', () => {
    beforeEach(() => {
      mockUseStore.mockImplementation((_store, selector) => {
        const state = {
          meta: {
            errorMap: {},
            errors: [{ message: 'valid_error' }, { message: null }, { message: undefined }],
          },
        }

        return selector(state)
      })
    })

    describe('WHEN called', () => {
      it('THEN should filter out falsy messages', () => {
        const { result } = renderHook(() => useFieldError())

        expect(result.current).toBe('valid_error')
      })
    })
  })

  describe('GIVEN combined options', () => {
    beforeEach(() => {
      mockUseStore.mockImplementation((_store, selector) => {
        const state = {
          meta: {
            errorMap: {},
            errors: [{ message: 'error_to_show' }, { message: 'error_to_hide' }],
          },
        }

        return selector(state)
      })
    })

    describe('WHEN showOnlyErrors and translateErrors are both set', () => {
      it('THEN should filter first then translate', () => {
        const { result } = renderHook(() =>
          useFieldError({
            showOnlyErrors: ['error_to_show'],
            translateErrors: true,
          }),
        )

        expect(mockTranslate).toHaveBeenCalledWith('error_to_show')
        expect(mockTranslate).not.toHaveBeenCalledWith('error_to_hide')
        expect(result.current).toBe('translated_error_to_show')
      })
    })
  })
})
