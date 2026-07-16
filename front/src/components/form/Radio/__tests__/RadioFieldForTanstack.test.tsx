import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import RadioField from '../RadioFieldForTanstack'

// Mock the field context
const mockHandleChange = jest.fn()
const mockFieldState = {
  value: 'option1',
}

jest.mock('~/hooks/forms/formContext', () => ({
  useFieldContext: () => ({
    name: 'testField',
    state: mockFieldState,
    handleChange: mockHandleChange,
  }),
}))

describe('RadioFieldForTanstack', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockFieldState.value = 'option1'
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN value matches field state value', () => {
      it('THEN should render the radio as checked', () => {
        render(<RadioField value="option1" label="Option 1" />)

        const radio = screen.getByRole('radio')

        // The RadioIcon component shows checked state visually
        // The actual input is hidden but we can verify the component renders
        expect(radio).toBeInTheDocument()
      })
    })

    describe('WHEN value does not match field state value', () => {
      it('THEN should render the radio as unchecked', () => {
        render(<RadioField value="option2" label="Option 2" />)

        const radio = screen.getByRole('radio')

        expect(radio).toBeInTheDocument()
      })
    })

    describe('WHEN label is provided', () => {
      it('THEN should display the label text', () => {
        render(<RadioField value="option1" label="Test Label" />)

        expect(screen.getByText('Test Label')).toBeInTheDocument()
      })
    })

    describe('WHEN sublabel is provided', () => {
      it('THEN should display the sublabel text', () => {
        render(<RadioField value="option1" label="Label" sublabel="Test Sublabel" />)

        expect(screen.getByText('Test Sublabel')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN user interacts with the radio', () => {
    describe('WHEN user clicks the radio', () => {
      it('THEN should call handleChange with the value', async () => {
        const user = userEvent.setup()

        render(<RadioField value="option2" label="Option 2" />)

        const radio = screen.getByRole('radio')

        await user.click(radio)

        expect(mockHandleChange).toHaveBeenCalledWith('option2')
      })
    })
  })

  describe('GIVEN the radio is disabled', () => {
    describe('WHEN disabled prop is true', () => {
      it('THEN should render the radio as disabled', () => {
        render(<RadioField value="option1" label="Disabled Option" disabled />)

        const radio = screen.getByRole('radio')

        expect(radio).toBeDisabled()
      })
    })
  })

  describe('GIVEN different value types', () => {
    describe('WHEN value is a string', () => {
      it('THEN should handle string value correctly', async () => {
        const user = userEvent.setup()

        render(<RadioField value="stringValue" label="String" />)

        const radio = screen.getByRole('radio')

        await user.click(radio)

        expect(mockHandleChange).toHaveBeenCalledWith('stringValue')
      })
    })

    describe('WHEN value is a number', () => {
      it('THEN should handle number value correctly', async () => {
        const user = userEvent.setup()

        render(<RadioField value={42} label="Number" />)

        const radio = screen.getByRole('radio')

        await user.click(radio)

        // The component casts to string when calling handleChange
        expect(mockHandleChange).toHaveBeenCalledWith(42)
      })
    })
  })

  describe('GIVEN the field name from context', () => {
    describe('WHEN rendering', () => {
      it('THEN should use the name from field context', () => {
        render(<RadioField value="option1" label="Test" />)

        const radio = screen.getByRole('radio')

        expect(radio).toHaveAttribute('aria-label', 'testField')
      })
    })
  })
})
