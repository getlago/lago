import { render } from '@testing-library/react'

import { ComboBoxInput } from '../ComboBoxInput'
import { ComboBoxInputProps } from '../types'

const buildProps = (disabled: boolean): ComboBoxInputProps => ({
  params: {
    id: 'test-combobox',
    inputProps: {
      onChange: jest.fn(),
      onMouseDown: jest.fn(),
      value: '',
    },
    InputProps: {
      ref: null,
      className: '',
      startAdornment: undefined,
      endAdornment: undefined,
    },
    disabled,
    fullWidth: true,
    size: 'small' as const,
  } as ComboBoxInputProps['params'],
  name: 'test',
  placeholder: 'Select',
  hasValueSelected: false,
})

describe('ComboBoxInput', () => {
  describe('GIVEN the chevron button', () => {
    it('WHEN the combobox is disabled THEN the chevron button should be disabled', () => {
      const { container } = render(<ComboBoxInput {...buildProps(true)} />)

      const chevronButton = container.querySelector(
        '.MuiInputAdornment-positionEnd button:last-of-type',
      ) as HTMLButtonElement

      expect(chevronButton).toBeDisabled()
    })

    it('WHEN the combobox is not disabled THEN the chevron button should not be disabled', () => {
      const { container } = render(<ComboBoxInput {...buildProps(false)} />)

      const chevronButton = container.querySelector(
        '.MuiInputAdornment-positionEnd button:last-of-type',
      ) as HTMLButtonElement

      expect(chevronButton).not.toBeDisabled()
    })
  })
})
