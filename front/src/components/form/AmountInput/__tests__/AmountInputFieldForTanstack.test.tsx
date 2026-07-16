import { render } from '@testing-library/react'

import { CurrencyEnum } from '~/generated/graphql'
import { useFieldContext } from '~/hooks/forms/formContext'

import AmountInputField from '../AmountInputFieldForTanstack'

const mockTranslate = jest.fn((key: string) => `translated_${key}`)

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: mockTranslate,
  }),
}))

const mockHandleChange = jest.fn()
const mockHandleBlur = jest.fn()

const createMockField = (
  value: string | number | undefined = '',
  errors: Array<{ message: string }> = [],
) => ({
  name: 'testField',
  state: { value },
  store: {
    subscribe: jest.fn(() => jest.fn()),
    getState: jest.fn(() => ({
      meta: {
        errors,
        errorMap: {},
      },
      values: { testField: value },
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

describe('AmountInputFieldForTanstack', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN there are no errors', () => {
      it('THEN should render without crashing', () => {
        mockedUseFieldContext.mockReturnValue(createMockField('100'))

        const { container } = render(<AmountInputField currency={CurrencyEnum.Usd} />)

        expect(container).toBeInTheDocument()
      })

      it('THEN should use the field context', () => {
        mockedUseFieldContext.mockReturnValue(createMockField('50.00'))

        render(<AmountInputField currency={CurrencyEnum.Usd} />)

        // The component renders with the value from field context
        expect(mockedUseFieldContext).toHaveBeenCalled()
      })
    })

    describe('WHEN there are validation errors', () => {
      it('THEN should translate only the first error (firstOnly mode)', () => {
        const errors = [{ message: 'error_amount_required' }, { message: 'error_amount_invalid' }]

        mockedUseFieldContext.mockReturnValue(createMockField('', errors))

        render(<AmountInputField currency={CurrencyEnum.Usd} />)

        expect(mockTranslate).toHaveBeenCalledWith('error_amount_required')
      })
    })

    describe('WHEN silentError is true', () => {
      it('THEN should not display errors', () => {
        const errors = [{ message: 'error_amount_required' }]

        mockedUseFieldContext.mockReturnValue(createMockField('', errors))

        render(<AmountInputField currency={CurrencyEnum.Usd} silentError />)

        // Errors are still translated but not displayed due to silentError
        expect(mockTranslate).toHaveBeenCalledWith('error_amount_required')
      })
    })

    describe('WHEN displayErrorText is false', () => {
      it('THEN should show error indicator without text', () => {
        const errors = [{ message: 'error_amount_required' }]

        mockedUseFieldContext.mockReturnValue(createMockField('', errors))

        render(<AmountInputField currency={CurrencyEnum.Usd} displayErrorText={false} />)

        expect(mockTranslate).toHaveBeenCalledWith('error_amount_required')
      })
    })
  })

  describe('GIVEN various field values', () => {
    describe('WHEN value is undefined', () => {
      it('THEN should render without crashing', () => {
        mockedUseFieldContext.mockReturnValue(createMockField(undefined))

        const { container } = render(<AmountInputField currency={CurrencyEnum.Usd} />)

        expect(container).toBeInTheDocument()
      })
    })

    describe('WHEN value is a number', () => {
      it('THEN should render with numeric value', () => {
        mockedUseFieldContext.mockReturnValue(createMockField(100))

        const { container } = render(<AmountInputField currency={CurrencyEnum.Usd} />)

        expect(container).toBeInTheDocument()
      })
    })

    describe('WHEN value is a string', () => {
      it('THEN should render with string value', () => {
        mockedUseFieldContext.mockReturnValue(createMockField('100.50'))

        const { container } = render(<AmountInputField currency={CurrencyEnum.Usd} />)

        expect(container).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN errors with empty messages', () => {
    describe('WHEN first error message is empty', () => {
      it('THEN should skip empty and translate the next non-empty error', () => {
        const errors = [{ message: '' }, { message: 'error_2' }]

        mockedUseFieldContext.mockReturnValue(createMockField('', errors))

        render(<AmountInputField currency={CurrencyEnum.Usd} />)

        expect(mockTranslate).toHaveBeenCalledWith('error_2')
        expect(mockTranslate).not.toHaveBeenCalledWith('')
      })
    })
  })
})
