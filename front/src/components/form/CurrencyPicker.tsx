import { ComboBox } from '~/components/form/ComboBox/ComboBox'
import { ComboBoxProps } from '~/components/form/ComboBox/types'
import { CurrencyEnum } from '~/generated/graphql'

const CURRENCY_DATA = Object.values(CurrencyEnum).map((value) => ({ value }))

// ComboBoxProps is a union (basic | grouped). We narrow to the basic branch
// — discriminated by `renderGroupHeader?: never` — and then strip the props
// we own (`data`, `value`, `onChange`).
type FlatComboBoxProps = Extract<ComboBoxProps, { renderGroupHeader?: never }>

type CurrencyPickerProps = Omit<FlatComboBoxProps, 'data' | 'value' | 'onChange'> & {
  value: CurrencyEnum | undefined
  onChange: (currency: CurrencyEnum) => void
  /**
   * When provided, the ComboBox becomes clearable: the user can reset the
   * selection back to the placeholder state, and this callback fires.
   */
  onClear?: () => void
}

export const CURRENCY_PICKER_DATA_TEST = 'currency-picker'

export const CurrencyPicker = ({
  value,
  onChange,
  onClear,
  PopperProps,
  ...rest
}: CurrencyPickerProps) => (
  <ComboBox
    {...rest}
    data-test={CURRENCY_PICKER_DATA_TEST}
    data={CURRENCY_DATA}
    value={value}
    onChange={(next) => {
      if (next) {
        onChange(next as CurrencyEnum)
      } else if (onClear) {
        onClear()
      }
    }}
    disableClearable={!onClear}
    PopperProps={{ displayInDialog: true, ...PopperProps }}
  />
)
