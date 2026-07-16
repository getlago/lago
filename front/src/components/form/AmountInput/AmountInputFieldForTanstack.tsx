import { forwardRef } from 'react'

import { useFieldContext } from '~/hooks/forms/formContext'
import { useFieldError } from '~/hooks/forms/useFieldError'

import { AmountInput, AmountInputProps } from './AmountInput'

interface AmountInputFieldProps extends Omit<
  AmountInputProps,
  'name' | 'value' | 'onChange' | 'onBlur' | 'error'
> {
  silentError?: boolean
  displayErrorText?: boolean
  errorOverride?: string | boolean
}

const AmountInputField = forwardRef<HTMLDivElement, AmountInputFieldProps>(
  ({ silentError = false, displayErrorText = true, errorOverride, ...props }, ref) => {
    const field = useFieldContext<string | number | undefined>()

    const finalError = useFieldError({
      silentError,
      displayErrorText,
      translateErrors: true,
      firstOnly: true,
    })

    return (
      <AmountInput
        ref={ref}
        {...props}
        name={field.name}
        value={field.state.value}
        onChange={(value) => field.handleChange(value)}
        onBlur={field.handleBlur}
        error={errorOverride ?? finalError}
      />
    )
  },
)

AmountInputField.displayName = 'AmountInputField'

export default AmountInputField
