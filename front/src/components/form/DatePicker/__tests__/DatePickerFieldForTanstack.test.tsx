import { render } from '@testing-library/react'

import { useFieldContext } from '~/hooks/forms/formContext'

import DatePickerField from '../DatePickerFieldForTanstack'

const mockTranslate = jest.fn((key: string) => `translated_${key}`)

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: mockTranslate,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: {
      id: 'org-1',
      timezone: 'UTC',
    },
  }),
}))

const mockHandleChange = jest.fn()
const mockHandleBlur = jest.fn()

const createMockField = (
  value: string | undefined = '',
  errors: Array<{ message: string }> = [],
) => ({
  name: 'testDateField',
  state: { value },
  store: {
    subscribe: jest.fn(() => jest.fn()),
    getState: jest.fn(() => ({
      meta: {
        errors,
        errorMap: {},
      },
      values: { testDateField: value },
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

describe('DatePickerFieldForTanstack', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN there are no errors', () => {
      it('THEN should render without crashing', () => {
        mockedUseFieldContext.mockReturnValue(createMockField('2024-01-15'))

        const { container } = render(<DatePickerField />)

        expect(container).toBeInTheDocument()
      })

      it('THEN should use the field context', () => {
        mockedUseFieldContext.mockReturnValue(createMockField('2024-06-20'))

        render(<DatePickerField />)

        expect(mockedUseFieldContext).toHaveBeenCalled()
      })

      it('THEN should render the description when provided', () => {
        mockedUseFieldContext.mockReturnValue(createMockField())

        const { getByText } = render(<DatePickerField description="Pick a date" />)

        expect(getByText('Pick a date')).toBeInTheDocument()
      })
    })

    describe('WHEN there are validation errors', () => {
      it('THEN should translate error messages', () => {
        const errors = [{ message: 'error_date_required' }, { message: 'error_date_invalid' }]

        mockedUseFieldContext.mockReturnValue(createMockField('', errors))

        render(<DatePickerField />)

        expect(mockTranslate).toHaveBeenCalledWith('error_date_required')
        expect(mockTranslate).toHaveBeenCalledWith('error_date_invalid')
      })

      it('THEN should translate all provided error messages', () => {
        const errors = [{ message: 'error_1' }, { message: 'error_2' }]

        mockedUseFieldContext.mockReturnValue(createMockField('', errors))

        render(<DatePickerField />)

        // Both errors should be translated (along with any other translate calls from child components)
        expect(mockTranslate).toHaveBeenCalledWith('error_1')
        expect(mockTranslate).toHaveBeenCalledWith('error_2')
      })
    })

    describe('WHEN silentError is true', () => {
      it('THEN should not display errors', () => {
        const errors = [{ message: 'error_date_required' }]

        mockedUseFieldContext.mockReturnValue(createMockField('', errors))

        render(<DatePickerField silentError />)

        // Errors are still translated but silentError prevents display
        expect(mockTranslate).toHaveBeenCalledWith('error_date_required')
      })
    })

    describe('WHEN displayErrorText is false', () => {
      it('THEN should show error indicator without text', () => {
        const errors = [{ message: 'error_date_required' }]

        mockedUseFieldContext.mockReturnValue(createMockField('', errors))

        render(<DatePickerField displayErrorText={false} />)

        expect(mockTranslate).toHaveBeenCalledWith('error_date_required')
      })
    })
  })

  describe('GIVEN various field values', () => {
    describe('WHEN value is undefined', () => {
      it('THEN should render without crashing', () => {
        mockedUseFieldContext.mockReturnValue(createMockField(undefined))

        const { container } = render(<DatePickerField />)

        expect(container).toBeInTheDocument()
      })
    })

    describe('WHEN value is an empty string', () => {
      it('THEN should render without crashing', () => {
        mockedUseFieldContext.mockReturnValue(createMockField(''))

        const { container } = render(<DatePickerField />)

        expect(container).toBeInTheDocument()
      })
    })

    describe('WHEN value is a valid ISO date string', () => {
      it('THEN should render with the date value', () => {
        mockedUseFieldContext.mockReturnValue(createMockField('2024-12-31T23:59:59Z'))

        const { container } = render(<DatePickerField />)

        expect(container).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN errors with empty messages', () => {
    describe('WHEN some error messages are empty', () => {
      it('THEN should filter out empty messages', () => {
        const errors = [{ message: 'error_1' }, { message: '' }, { message: 'error_2' }]

        mockedUseFieldContext.mockReturnValue(createMockField('', errors))

        render(<DatePickerField />)

        expect(mockTranslate).toHaveBeenCalledWith('error_1')
        expect(mockTranslate).toHaveBeenCalledWith('error_2')
        expect(mockTranslate).not.toHaveBeenCalledWith('')
      })
    })
  })

  describe('GIVEN props are passed through', () => {
    describe('WHEN placeholder is provided', () => {
      it('THEN should pass placeholder to DatePicker', () => {
        mockedUseFieldContext.mockReturnValue(createMockField(''))

        const { container } = render(<DatePickerField placeholder="Select a date" />)

        expect(container).toBeInTheDocument()
      })
    })

    describe('WHEN label is provided', () => {
      it('THEN should pass label to DatePicker', () => {
        mockedUseFieldContext.mockReturnValue(createMockField(''))

        const { container } = render(<DatePickerField label="Expiration Date" />)

        expect(container).toBeInTheDocument()
      })
    })

    describe('WHEN disabled is true', () => {
      it('THEN should pass disabled to DatePicker', () => {
        mockedUseFieldContext.mockReturnValue(createMockField(''))

        const { container } = render(<DatePickerField disabled />)

        expect(container).toBeInTheDocument()
      })
    })
  })
})
