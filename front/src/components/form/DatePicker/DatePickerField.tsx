import { FormikProps } from 'formik'
import _get from 'lodash/get'
import _isEqual from 'lodash/isEqual'
import { memo } from 'react'

import { DatePicker, DatePickerProps } from './DatePicker'

interface DatePickerFieldFormProps extends Omit<DatePickerProps, 'name' | 'onChange' | 'onError'> {
  name: string
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  formikProps: FormikProps<any>
}

export const DatePickerField = memo(
  ({ name, formikProps, ...props }: DatePickerFieldFormProps) => {
    const { values, errors, touched, handleBlur, setFieldValue, setFieldError } = formikProps

    return (
      <DatePicker
        name={name}
        onBlur={handleBlur}
        value={_get(values, name)}
        error={touched[name] ? (errors[name] as string) : undefined}
        onError={(err) => setFieldError(name, err)}
        onChange={(value: string | null | undefined) => {
          setFieldValue(name, value)
        }}
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
      prevFormikProps.values[prevName] === nextformikProps.values[nextName] &&
      prevFormikProps.errors[prevName] === nextformikProps.errors[nextName] &&
      prevFormikProps.touched[prevName] === nextformikProps.touched[nextName]
    )
  },
)

DatePickerField.displayName = 'DatePickerField'
