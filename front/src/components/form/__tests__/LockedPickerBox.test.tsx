import { configure, render, screen } from '@testing-library/react'

import { LOCKED_PICKER_BOX_DATA_TEST } from '../LockedPickerBox'

configure({ testIdAttribute: 'data-test' })

const mockOnClick = jest.fn()

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

jest.mock('../TextInput', () => ({
  TextInput: ({
    placeholder,
    onClick,
    inputProps,
    InputProps,
  }: {
    placeholder?: string
    onClick?: () => void
    inputProps?: { readOnly?: boolean; 'data-test'?: string }
    InputProps?: { readOnly?: boolean; endAdornment?: React.ReactNode }
  }) => (
    // eslint-disable-next-line jsx-a11y/click-events-have-key-events, jsx-a11y/no-static-element-interactions
    <div data-test="text-input-wrapper" onClick={onClick}>
      <input
        data-test={inputProps?.['data-test']}
        placeholder={placeholder}
        readOnly={inputProps?.readOnly}
      />
      {InputProps?.endAdornment}
    </div>
  ),
}))

jest.mock('lago-design-system', () => ({
  Icon: ({ name, size }: { name: string; size: string }) => (
    <span data-test="icon" data-icon-name={name} data-icon-size={size} />
  ),
}))

describe('LockedPickerBox', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { LockedPickerBox } = require('../LockedPickerBox')

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN a LockedPickerBox with a placeholder', () => {
    describe('WHEN it renders', () => {
      it('THEN should display the placeholder text', () => {
        render(<LockedPickerBox placeholder="Select a plan" onClick={mockOnClick} />)

        const input = screen.getByTestId(LOCKED_PICKER_BOX_DATA_TEST) as HTMLInputElement

        expect(input.placeholder).toBe('Select a plan')
      })
    })
  })

  describe('GIVEN a LockedPickerBox with onClick', () => {
    describe('WHEN the box is clicked', () => {
      it('THEN should fire the onClick handler', () => {
        render(<LockedPickerBox placeholder="Select" onClick={mockOnClick} />)

        screen.getByTestId('text-input-wrapper').click()

        expect(mockOnClick).toHaveBeenCalledTimes(1)
      })
    })
  })

  describe('GIVEN a LockedPickerBox', () => {
    describe('WHEN it renders', () => {
      it('THEN should have a read-only input', () => {
        render(<LockedPickerBox placeholder="Select" onClick={mockOnClick} />)

        const input = screen.getByTestId(LOCKED_PICKER_BOX_DATA_TEST) as HTMLInputElement

        expect(input.readOnly).toBe(true)
      })
    })
  })

  describe('GIVEN a LockedPickerBox with a custom icon', () => {
    it.each([
      ['sparkles', undefined],
      ['lock', 'lock'],
      ['star-filled', 'star-filled'],
    ])('THEN should show icon "%s" when icon prop is %s', (expectedIcon, iconProp) => {
      render(<LockedPickerBox placeholder="Select" onClick={mockOnClick} icon={iconProp} />)

      const icon = screen.getByTestId('icon')

      expect(icon).toHaveAttribute('data-icon-name', expectedIcon)
    })
  })
})
