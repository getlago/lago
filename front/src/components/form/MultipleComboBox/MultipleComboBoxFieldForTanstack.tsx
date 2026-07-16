import { useStore } from '@tanstack/react-form'

import { getErrorToDisplay } from '~/core/form/getErrorToDisplay'
import { useFieldContext } from '~/hooks/forms/formContext'

import { MultipleComboBox } from './MultipleComboBox'
import {
  BasicMultipleComboBoxData,
  MultipleComboBoxData,
  MultipleComboBoxDataGrouped,
  MultipleComboBoxProps,
} from './types'

const MultipleComboBoxField = ({
  data,
  renderGroupHeader,
  ...props
}: Omit<MultipleComboBoxProps, 'name' | 'onChange' | 'value' | 'error'> & {
  dataTest?: string
}) => {
  const field = useFieldContext<MultipleComboBoxData[] | undefined>()

  const error = useStore(field.store, (state) => state.meta.errors)
    .map((e) => e.message)
    .join('')

  const errorMap = useStore(field.store, (state) => state.meta.errorMap)

  const finalError = getErrorToDisplay({
    error,
    errorMap,
  })

  return renderGroupHeader ? (
    <MultipleComboBox
      {...props}
      data={data as MultipleComboBoxDataGrouped[]}
      renderGroupHeader={renderGroupHeader}
      name={field.name}
      onChange={(value) => {
        field.handleChange(value)
      }}
      value={field.state.value}
      error={finalError}
      data-test={props.dataTest}
    />
  ) : (
    <MultipleComboBox
      {...props}
      data={data as BasicMultipleComboBoxData[]}
      name={field.name}
      onChange={(value) => {
        field.handleChange(value)
      }}
      value={field.state.value}
      error={finalError}
      data-test={props.dataTest}
    />
  )
}

export default MultipleComboBoxField
