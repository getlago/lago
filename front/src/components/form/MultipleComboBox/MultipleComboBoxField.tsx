import { FormikProps } from 'formik'
import _get from 'lodash/get'
import _isEqual from 'lodash/isEqual'
import { memo } from 'react'

import { MultipleComboBox } from './MultipleComboBox'
import {
  BasicMultipleComboBoxData,
  MultipleComboBoxDataGrouped,
  MultipleComboBoxProps,
} from './types'

interface MultipleComboBoxFieldProps extends Omit<
  MultipleComboBoxProps,
  'onChange' | 'value' | 'name'
> {
  name: string
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  formikProps: FormikProps<any>
  isEmptyNull?: boolean // If false, on field reset the Multiplecombobox will return an empty string
}

export const MultipleComboBoxField = memo(
  ({
    name,
    isEmptyNull = true,
    formikProps,
    renderGroupHeader,
    data,
    ...props
  }: MultipleComboBoxFieldProps) => {
    const { setFieldValue, values, errors, touched } = formikProps

    return renderGroupHeader ? (
      <MultipleComboBox
        name={name}
        data={data as MultipleComboBoxDataGrouped[]}
        renderGroupHeader={renderGroupHeader}
        value={_get(values, name)}
        error={touched[name] ? (errors[name] as string) : undefined}
        onChange={(newValue) => setFieldValue(name, newValue || (isEmptyNull ? null : ''))}
        {...props}
      />
    ) : (
      <MultipleComboBox
        data={data as BasicMultipleComboBoxData[]}
        name={name}
        value={_get(values, name)}
        error={touched[name] ? (errors[name] as string) : undefined}
        onChange={(newValue) => setFieldValue(name, newValue || (isEmptyNull ? null : ''))}
        {...props}
      />
    )
  },
  (
    { formikProps: prevFormikProps, name: prevName, ...prev },
    { formikProps: nextformikProps, name: nextName, ...next },
  ) => {
    return (
      _isEqual(prev, next) &&
      prevName === nextName &&
      _get(prevFormikProps.values, prevName) === _get(nextformikProps.values, nextName) &&
      _get(prevFormikProps.errors, prevName) === _get(nextformikProps.errors, nextName) &&
      _get(prevFormikProps.touched, prevName) === _get(nextformikProps.touched, nextName)
    )
  },
)

MultipleComboBoxField.displayName = 'MultipleComboBoxField'
