import { useStore } from '@tanstack/react-form'

import { getErrorToDisplay } from '~/core/form/getErrorToDisplay'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useFieldContext } from '~/hooks/forms/formContext'

import { TextInput, TextInputProps } from './TextInput'

const TextInputField = ({
  silentError = false,
  displayErrorText = true,
  showOnlyErrors,
  ...props
}: Omit<TextInputProps, 'name' | 'value' | 'onChange' | 'onBlur' | 'error'> & {
  silentError?: boolean
  displayErrorText?: boolean
  showOnlyErrors?: string[]
}) => {
  const field = useFieldContext<string>()
  const { translate } = useInternationalization()

  const errorMap = useStore(field.store, (state) => state.meta.errorMap)
  const allErrors = useStore(field.store, (state) => state.meta.errors)
    .map((e) => e.message)
    .filter(Boolean)

  // Filter errors if showOnlyErrors is provided
  const filteredErrors = showOnlyErrors
    ? allErrors.filter((err) => showOnlyErrors.includes(err as string))
    : allErrors

  // Translate each error key and join them before passing to getErrorToDisplay
  const translatedError = filteredErrors.map((errorKey) => translate(errorKey as string)).join('\n')

  const finalError = getErrorToDisplay({
    error: translatedError,
    errorMap,
    silentError,
    displayErrorText,
  })

  return (
    <TextInput
      {...props}
      name={field.name}
      value={field.state.value}
      onChange={(value) => field.handleChange(value)}
      onBlur={field.handleBlur}
      error={finalError}
    />
  )
}

export default TextInputField
