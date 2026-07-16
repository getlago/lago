import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { useFieldContext } from '~/hooks/forms/formContext'
import { useFieldError } from '~/hooks/forms/useFieldError'

import ButtonSelectorField from '../ButtonSelectorFieldForTanstack'

jest.mock('~/hooks/forms/formContext', () => ({
  useFieldContext: jest.fn(),
}))

jest.mock('~/hooks/forms/useFieldError', () => ({
  useFieldError: jest.fn(),
}))

const mockHandleChange = jest.fn()
const mockedUseFieldError = useFieldError as jest.Mock

const createMockField = (value: string | number | boolean = '') => ({
  name: 'testField',
  state: { value },
  store: {
    subscribe: jest.fn(() => jest.fn()),
    getState: jest.fn(() => ({
      meta: { errors: [], errorMap: {} },
      values: { testField: value },
    })),
  },
  handleChange: mockHandleChange,
  handleBlur: jest.fn(),
})

const mockedUseFieldContext = useFieldContext as jest.Mock

describe('ButtonSelectorFieldForTanstack', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockedUseFieldError.mockReturnValue(undefined)
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN there are no errors', () => {
      it('THEN should render without crashing', () => {
        mockedUseFieldContext.mockReturnValue(createMockField('option1'))

        const { container } = render(
          <ButtonSelectorField
            options={[
              { label: 'Option 1', value: 'option1' },
              { label: 'Option 2', value: 'option2' },
            ]}
          />,
        )

        expect(container).toBeInTheDocument()
      })

      it('THEN should use the field context', () => {
        mockedUseFieldContext.mockReturnValue(createMockField('option1'))

        render(
          <ButtonSelectorField
            options={[
              { label: 'Option 1', value: 'option1' },
              { label: 'Option 2', value: 'option2' },
            ]}
          />,
        )

        expect(mockedUseFieldContext).toHaveBeenCalled()
      })
    })

    describe('WHEN a user clicks an option', () => {
      it('THEN should call handleChange with the selected value', async () => {
        const user = userEvent.setup()

        mockedUseFieldContext.mockReturnValue(createMockField('option1'))

        render(
          <ButtonSelectorField
            options={[
              { label: 'Option 1', value: 'option1' },
              { label: 'Option 2', value: 'option2' },
            ]}
          />,
        )

        const option2Button = screen.getByText('Option 2')

        await user.click(option2Button)

        expect(mockHandleChange).toHaveBeenCalledWith('option2')
      })
    })

    describe('WHEN there are validation errors', () => {
      it('THEN should call useFieldError with translateErrors true', () => {
        mockedUseFieldContext.mockReturnValue(createMockField(''))
        mockedUseFieldError.mockReturnValue('Field is required')

        render(
          <ButtonSelectorField
            options={[
              { label: 'Option 1', value: 'option1' },
              { label: 'Option 2', value: 'option2' },
            ]}
          />,
        )

        expect(mockedUseFieldError).toHaveBeenCalledWith({
          translateErrors: true,
          noBoolean: true,
        })
      })
    })

    describe('WHEN value is a boolean', () => {
      it('THEN should render with the boolean value', () => {
        mockedUseFieldContext.mockReturnValue(createMockField(true))

        const { container } = render(
          <ButtonSelectorField
            options={[
              { label: 'Yes', value: true },
              { label: 'No', value: false },
            ]}
          />,
        )

        expect(container).toBeInTheDocument()
      })
    })

    describe('WHEN value is a number', () => {
      it('THEN should render with the numeric value', () => {
        mockedUseFieldContext.mockReturnValue(createMockField(42))

        const { container } = render(
          <ButtonSelectorField
            options={[
              { label: '42', value: 42 },
              { label: '100', value: 100 },
            ]}
          />,
        )

        expect(container).toBeInTheDocument()
      })
    })
  })
})
