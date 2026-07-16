import { useFieldContext } from '~/hooks/forms/formContext'
import { useFieldError } from '~/hooks/forms/useFieldError'

import { ButtonSelector, ButtonSelectorProps } from './ButtonSelector'

type ValueType = string | number | boolean

const ButtonSelectorField = (props: Omit<ButtonSelectorProps, 'value' | 'onChange' | 'error'>) => {
  const field = useFieldContext<ValueType>()

  const finalError = useFieldError({ translateErrors: true, noBoolean: true })

  return (
    <ButtonSelector
      {...props}
      value={field.state.value}
      onChange={(value) => field.handleChange(value)}
      error={finalError}
    />
  )
}

export default ButtonSelectorField
