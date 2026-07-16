import { render } from '@testing-library/react'

import { useFieldContext } from '~/hooks/forms/formContext'

import TextInputField from '../TextInputFieldForTanstack'

const mockTranslate = jest.fn((key: string) => `translated_${key}`)

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: mockTranslate,
  }),
}))

const mockHandleChange = jest.fn()
const mockHandleBlur = jest.fn()

const createMockField = (errors: Array<{ message: string }> = []) => ({
  name: 'testField',
  state: { value: '' },
  store: {
    subscribe: jest.fn(() => jest.fn()),
    getState: jest.fn(() => ({
      meta: {
        errors,
        errorMap: {},
      },
      values: { testField: '' },
    })),
  },
  handleChange: mockHandleChange,
  handleBlur: mockHandleBlur,
})

jest.mock('~/hooks/forms/formContext', () => ({
  useFieldContext: jest.fn(),
}))

jest.mock('@tanstack/react-form', () => ({
  useStore: jest.fn((store, selector) => selector(store.getState())),
}))

const mockedUseFieldContext = useFieldContext as jest.Mock

describe('TextInputFieldForTanstack', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('showOnlyErrors filtering', () => {
    it('shows all errors when showOnlyErrors is not provided', () => {
      const errors = [{ message: 'error_1' }, { message: 'error_2' }, { message: 'error_3' }]

      mockedUseFieldContext.mockReturnValue(createMockField(errors))

      render(<TextInputField />)

      expect(mockTranslate).toHaveBeenCalledWith('error_1')
      expect(mockTranslate).toHaveBeenCalledWith('error_2')
      expect(mockTranslate).toHaveBeenCalledWith('error_3')
    })

    it('filters errors to only show specified ones when showOnlyErrors is provided', () => {
      const errors = [{ message: 'error_1' }, { message: 'error_2' }, { message: 'error_3' }]

      mockedUseFieldContext.mockReturnValue(createMockField(errors))

      render(<TextInputField showOnlyErrors={['error_2']} />)

      expect(mockTranslate).not.toHaveBeenCalledWith('error_1')
      expect(mockTranslate).toHaveBeenCalledWith('error_2')
      expect(mockTranslate).not.toHaveBeenCalledWith('error_3')
    })

    it('shows multiple specified errors when showOnlyErrors contains multiple values', () => {
      const errors = [{ message: 'error_1' }, { message: 'error_2' }, { message: 'error_3' }]

      mockedUseFieldContext.mockReturnValue(createMockField(errors))

      render(<TextInputField showOnlyErrors={['error_1', 'error_3']} />)

      expect(mockTranslate).toHaveBeenCalledWith('error_1')
      expect(mockTranslate).not.toHaveBeenCalledWith('error_2')
      expect(mockTranslate).toHaveBeenCalledWith('error_3')
    })

    it('shows no errors when showOnlyErrors does not match any errors', () => {
      const errors = [{ message: 'error_1' }, { message: 'error_2' }]

      mockedUseFieldContext.mockReturnValue(createMockField(errors))

      render(<TextInputField showOnlyErrors={['non_existent_error']} />)

      expect(mockTranslate).not.toHaveBeenCalledWith('error_1')
      expect(mockTranslate).not.toHaveBeenCalledWith('error_2')
    })

    it('shows no errors when there are no errors and showOnlyErrors is provided', () => {
      mockedUseFieldContext.mockReturnValue(createMockField([]))

      render(<TextInputField showOnlyErrors={['error_1']} />)

      expect(mockTranslate).not.toHaveBeenCalled()
    })

    it('shows no errors when there are no errors and showOnlyErrors is not provided', () => {
      mockedUseFieldContext.mockReturnValue(createMockField([]))

      render(<TextInputField />)

      expect(mockTranslate).not.toHaveBeenCalled()
    })
  })
})
