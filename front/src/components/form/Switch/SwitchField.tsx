import { FormikProps } from 'formik'
import _isEqual from 'lodash/isEqual'
import { memo } from 'react'

import { Switch, SwitchProps } from './Switch'

interface SwitchFieldFormProps extends SwitchProps {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  formikProps: FormikProps<any>
}

export const SwitchField = memo(
  ({ name, formikProps, ...props }: SwitchFieldFormProps) => {
    return (
      <Switch
        name={name}
        checked={!!formikProps.values[name]}
        onChange={(value) => {
          formikProps.setFieldValue(name, value)
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

SwitchField.displayName = 'SwitchField'
