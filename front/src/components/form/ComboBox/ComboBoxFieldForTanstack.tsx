import { useStore } from '@tanstack/react-form'

import { getErrorToDisplay } from '~/core/form/getErrorToDisplay'
import { useFieldContext } from '~/hooks/forms/formContext'

import { BasicComboBoxData, ComboBox, ComboboxDataGrouped, ComboBoxProps } from './'

const ComboBoxField = ({
  data,
  renderGroupHeader,
  displayErrorText = true,
  ...props
}: Omit<ComboBoxProps, 'name' | 'onChange' | 'value' | 'error'> & {
  dataTest?: string
  displayErrorText?: boolean
}) => {
  const field = useFieldContext<string | undefined>()

  const error = useStore(field.store, (state) => state.meta.errors)
    .map((e) => e.message)
    .join('')

  const errorMap = useStore(field.store, (state) => state.meta.errorMap)

  const finalError = getErrorToDisplay({
    error,
    errorMap,
    displayErrorText,
  })

  const onChange = (value: string) => {
    if (value === '') {
      return field.handleChange(undefined)
    }

    return field.handleChange(value)
  }

  return renderGroupHeader ? (
    <ComboBox
      {...props}
      data={data as ComboboxDataGrouped[]}
      renderGroupHeader={renderGroupHeader}
      name={field.name}
      onChange={(value) => {
        onChange(value)
      }}
      value={field.state.value}
      error={finalError}
      data-test={props.dataTest}
    />
  ) : (
    <ComboBox
      {...props}
      data={data as BasicComboBoxData[]}
      name={field.name}
      onChange={(value) => {
        onChange(value)
      }}
      value={field.state.value}
      error={finalError}
      data-test={props.dataTest}
    />
  )
}

export default ComboBoxField
