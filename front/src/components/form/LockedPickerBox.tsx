import InputAdornment from '@mui/material/InputAdornment'
import { Icon, IconName } from 'lago-design-system'

import { tw } from '~/styles/utils'

import { TextInput } from './TextInput'

type LockedPickerBoxProps = {
  placeholder?: string
  onClick: () => void
  containerClassName?: string
  icon?: IconName
}

/**
 * Visual stand-in for a ComboBox used when interaction must be intercepted —
 * typically to surface a premium-gated state. Mirrors the look-and-feel of
 * the ComboBox (placeholder, right adornment) but the input is read-only and
 * clicks fire `onClick` rather than opening a dropdown.
 */
export const LOCKED_PICKER_BOX_DATA_TEST = 'locked-picker-box'

export const LockedPickerBox = ({
  placeholder,
  onClick,
  containerClassName,
  icon = 'sparkles',
}: LockedPickerBoxProps) => (
  <TextInput
    className={tw('cursor-pointer', containerClassName)}
    value=""
    placeholder={placeholder}
    onClick={onClick}
    InputProps={{
      readOnly: true,
      endAdornment: (
        <InputAdornment position="end">
          <span className="pointer-events-none flex size-7 cursor-pointer items-center justify-center">
            <Icon name={icon} size="small" />
          </span>
        </InputAdornment>
      ),
    }}
    inputProps={{
      readOnly: true,
      tabIndex: -1,
      className: 'cursor-pointer',
      'data-test': LOCKED_PICKER_BOX_DATA_TEST,
    }}
  />
)
