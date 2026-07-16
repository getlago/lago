import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import RadioGroupField from '../RadioGroupFieldForTanstack'

const mockHandleChange = jest.fn()

jest.mock('~/hooks/forms/formContext', () => ({
  useFieldContext: () => ({
    name: 'test-radio-field',
    state: { value: 'option-b' },
    handleChange: mockHandleChange,
  }),
}))

const defaultOptions = [
  { value: 'option-a', label: 'Option A', sublabel: 'Description A' },
  { value: 'option-b', label: 'Option B', sublabel: 'Description B' },
  { value: 'option-c', label: 'Option C' },
]

describe('RadioGroupFieldForTanstack', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the component is rendered with options', () => {
    describe('WHEN in default state', () => {
      it.each([
        ['Option A', 'option-a'],
        ['Option B', 'option-b'],
        ['Option C', 'option-c'],
      ])('THEN should display radio for %s', (_, value) => {
        render(<RadioGroupField options={defaultOptions} />)

        const radio = document.querySelector(
          `input[type="radio"][value="${value}"]`,
        ) as HTMLInputElement

        expect(radio).toBeInTheDocument()
      })

      it('THEN should have the correct radio checked based on field context value', () => {
        render(<RadioGroupField options={defaultOptions} />)

        const checkedRadio = document.querySelector(
          'input[type="radio"][value="option-b"]',
        ) as HTMLInputElement

        const uncheckedRadio = document.querySelector(
          'input[type="radio"][value="option-a"]',
        ) as HTMLInputElement

        expect(checkedRadio).toBeInTheDocument()
        expect(uncheckedRadio).toBeInTheDocument()

        // Check visual indicator - the checked radio has a filled circle (r="4")
        const checkedLabel = checkedRadio.closest('label')
        const checkedIndicator = checkedLabel?.querySelector('circle[r="4"]')

        expect(checkedIndicator).toBeInTheDocument()

        const uncheckedLabel = uncheckedRadio.closest('label')
        const uncheckedIndicator = uncheckedLabel?.querySelector('circle[r="4"]')

        expect(uncheckedIndicator).not.toBeInTheDocument()
      })
    })

    describe('WHEN user clicks a radio option', () => {
      it('THEN should call handleChange with the selected value', async () => {
        const user = userEvent.setup()

        render(<RadioGroupField options={defaultOptions} />)

        const radioA = document.querySelector(
          'input[type="radio"][value="option-a"]',
        ) as HTMLInputElement

        await user.click(radioA)

        expect(mockHandleChange).toHaveBeenCalledWith('option-a')
      })
    })
  })

  describe('GIVEN the component has a label', () => {
    describe('WHEN label is provided', () => {
      it('THEN should render the label as a legend', () => {
        render(<RadioGroupField options={defaultOptions} label="Choose an option" />)

        expect(screen.getByText('Choose an option')).toBeInTheDocument()
      })
    })

    describe('WHEN label is not provided', () => {
      it('THEN should not render a legend element', () => {
        render(<RadioGroupField options={defaultOptions} />)

        expect(screen.queryByText('Choose an option')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the component has a description', () => {
    describe('WHEN description is provided', () => {
      it('THEN should render the description text', () => {
        render(
          <RadioGroupField
            options={defaultOptions}
            description="Please select one of the following"
          />,
        )

        expect(screen.getByText('Please select one of the following')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the component is disabled', () => {
    describe('WHEN disabled is true at group level', () => {
      it('THEN should disable all radio inputs', () => {
        render(<RadioGroupField options={defaultOptions} disabled />)

        const radios = document.querySelectorAll('input[type="radio"]')

        radios.forEach((radio) => {
          expect(radio).toBeDisabled()
        })
      })
    })

    describe('WHEN a specific option is disabled', () => {
      it('THEN should only disable that option', () => {
        const optionsWithDisabled = [
          { value: 'option-a', label: 'Option A' },
          { value: 'option-b', label: 'Option B', disabled: true },
          { value: 'option-c', label: 'Option C' },
        ]

        render(<RadioGroupField options={optionsWithDisabled} />)

        const radioA = document.querySelector(
          'input[type="radio"][value="option-a"]',
        ) as HTMLInputElement
        const radioB = document.querySelector(
          'input[type="radio"][value="option-b"]',
        ) as HTMLInputElement
        const radioC = document.querySelector(
          'input[type="radio"][value="option-c"]',
        ) as HTMLInputElement

        expect(radioA).not.toBeDisabled()
        expect(radioB).toBeDisabled()
        expect(radioC).not.toBeDisabled()
      })
    })
  })
})
