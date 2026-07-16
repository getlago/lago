import { render } from '@testing-library/react'

import { useFieldContext } from '~/hooks/forms/formContext'

import MultipleComboBoxField from '../MultipleComboBoxFieldForTanstack'

jest.mock('~/hooks/forms/formContext', () => ({
  useFieldContext: jest.fn(),
}))

jest.mock('@tanstack/react-form', () => ({
  useStore: jest.fn((store, selector) => selector(store.getState())),
}))

const mockHandleChange = jest.fn()

const createMockField = (
  errors: Array<{ message: string }> = [],
  value: unknown[] | undefined = undefined,
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
    })),
  },
  handleChange: mockHandleChange,
})

const mockedUseFieldContext = useFieldContext as jest.Mock

describe('MultipleComboBoxFieldForTanstack', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the component is rendered without renderGroupHeader', () => {
    describe('WHEN there are no errors', () => {
      it('THEN should render without crashing', () => {
        mockedUseFieldContext.mockReturnValue(createMockField())

        const { container } = render(<MultipleComboBoxField data={[]} />)

        expect(container).toBeInTheDocument()
      })
    })

    describe('WHEN there are errors', () => {
      it('THEN should pass the error to MultipleComboBox', () => {
        const errors = [{ message: 'Invalid email' }]

        mockedUseFieldContext.mockReturnValue(createMockField(errors))

        const { container } = render(<MultipleComboBoxField data={[]} />)

        expect(container).toBeInTheDocument()
      })
    })

    describe('WHEN value is set', () => {
      it('THEN should pass the value to MultipleComboBox', () => {
        const value = [{ value: 'test@example.com' }]

        mockedUseFieldContext.mockReturnValue(createMockField([], value))

        const { container } = render(<MultipleComboBoxField data={[]} />)

        expect(container).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the component is rendered with renderGroupHeader', () => {
    describe('WHEN renderGroupHeader is provided', () => {
      it('THEN should render the grouped variant', () => {
        mockedUseFieldContext.mockReturnValue(createMockField())

        const renderGroupHeader: Record<string, React.ReactNode> = {
          groupA: <div>Group Header A</div>,
        }

        const { container } = render(
          <MultipleComboBoxField data={[]} renderGroupHeader={renderGroupHeader} />,
        )

        expect(container).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the component receives a dataTest prop', () => {
    describe('WHEN dataTest is provided', () => {
      it('THEN should pass it to the underlying component', () => {
        mockedUseFieldContext.mockReturnValue(createMockField())

        const { container } = render(<MultipleComboBoxField data={[]} dataTest="my-combobox" />)

        expect(container).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN multiple errors exist', () => {
    describe('WHEN errors are concatenated', () => {
      it('THEN should join error messages', () => {
        const errors = [{ message: 'Error 1' }, { message: 'Error 2' }]

        mockedUseFieldContext.mockReturnValue(createMockField(errors))

        const { container } = render(<MultipleComboBoxField data={[]} />)

        expect(container).toBeInTheDocument()
      })
    })
  })
})
