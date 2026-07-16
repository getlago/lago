import { FormikProps } from 'formik'
import _get from 'lodash/get'
import _isEqual from 'lodash/isEqual'
import { forwardRef, memo } from 'react'

import { Radio, RadioProps } from './Radio'

export interface RadioFieldProps extends Omit<RadioProps, 'checked' | 'name'> {
  name: string
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  formikProps: FormikProps<any>
}

export const RadioField = memo(
  forwardRef<HTMLLabelElement, RadioFieldProps>(
    ({ name, value, formikProps, ...props }: RadioFieldProps, ref) => {
      const { values, setFieldValue } = formikProps

      return (
        <Radio
          {...props}
          ref={ref}
          value={value}
          checked={_get(values, name) === value}
          onChange={() => setFieldValue(name, value)}
          name={name}
        />
      )
    },
  ),
  (
    { formikProps: prevFormikProps, name: prevName, ...prev },
    { formikProps: nextFormikProps, name: nextName, ...next },
  ) => {
    return (
      _isEqual(prev, next) &&
      prevName === nextName &&
      _get(prevFormikProps.values, prevName) === _get(nextFormikProps.values, nextName) &&
      _get(prevFormikProps.errors, prevName) === _get(nextFormikProps.errors, nextName) &&
      _get(prevFormikProps.touched, prevName) === _get(nextFormikProps.touched, nextName)
    )
  },
)

RadioField.displayName = 'RadioField'
