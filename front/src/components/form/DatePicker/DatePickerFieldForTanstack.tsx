import { useFieldContext } from '~/hooks/forms/formContext'
import { useFieldError } from '~/hooks/forms/useFieldError'

import { DatePicker, DatePickerProps } from './DatePicker'

const DatePickerField = (
  props: Omit<DatePickerProps, 'name' | 'value' | 'onChange' | 'onError' | 'error'> & {
    silentError?: boolean
    displayErrorText?: boolean
  },
) => {
  const { silentError = false, displayErrorText = true, ...rest } = props
  const field = useFieldContext<string | undefined>()

  const finalError = useFieldError({ silentError, displayErrorText, translateErrors: true })

  return (
    <DatePicker
      {...rest}
      name={field.name}
      value={field.state.value}
      onChange={(value) => field.handleChange(value ?? undefined)}
      error={typeof finalError === 'string' ? finalError : undefined}
    />
  )
}

export default DatePickerField
