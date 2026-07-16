import { FormikProps } from 'formik'
import _get from 'lodash/get'

import { Checkbox, CheckboxProps } from './Checkbox'

interface CheckboxFieldProps extends Omit<CheckboxProps, 'onChange' | 'name'> {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  formikProps: FormikProps<any>
  name: string
  onChange?: (value: boolean) => unknown
}

export const CheckboxField = ({ name, formikProps, onChange, ...props }: CheckboxFieldProps) => {
  const { values, errors, touched, setFieldValue } = formikProps

  return (
    <Checkbox
      name={name}
      value={_get(values, name)}
      onChange={(_, newValue) => {
        setFieldValue(name, newValue)

        onChange && onChange(newValue)
      }}
      error={_get(touched, name) ? (_get(errors, name) as string) : undefined}
      {...props}
    />
  )
}
