import { useStore } from '@tanstack/react-form'

import { getErrorToDisplay } from '~/core/form/getErrorToDisplay'
import { useFieldContext } from '~/hooks/forms/formContext'

import { Checkbox, CheckboxProps } from './Checkbox'

const CheckboxField = (
  props: Omit<CheckboxProps, 'name' | 'value' | 'onChange' | 'error'> & { dataTest?: string },
) => {
  const field = useFieldContext<boolean>()

  const error = useStore(field.store, (state) => state.meta.errors)
    .map((e) => e.message)
    .join('')

  const errorMap = useStore(field.store, (state) => state.meta.errorMap)
  const finalError = getErrorToDisplay({
    error,
    errorMap,
    noBoolean: true,
  })

  return (
    <Checkbox
      {...props}
      name={field.name}
      value={field.state.value}
      onChange={(_, newValue) => field.handleChange(newValue)}
      error={finalError}
      data-test={props.dataTest}
    />
  )
}

export default CheckboxField
