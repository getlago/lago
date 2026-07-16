import { FormikProps } from 'formik'
import _isEqual from 'lodash/isEqual'
import { memo } from 'react'

import { ButtonSelector, ButtonSelectorProps } from './ButtonSelector'

interface ButtonSelectorFieldProps extends Omit<ButtonSelectorProps, 'onChange'> {
  name: string
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  formikProps: FormikProps<any>
}

export const ButtonSelectorField = memo(
  ({ name, formikProps, ...props }: ButtonSelectorFieldProps) => {
    const { values, touched, errors, setFieldValue } = formikProps

    return (
      <ButtonSelector
        value={values[name]}
        onChange={(newValue) => setFieldValue(name, newValue)}
        error={touched[name] ? (errors[name] as string) : undefined}
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

ButtonSelectorField.displayName = 'ButtonSelectorField'
