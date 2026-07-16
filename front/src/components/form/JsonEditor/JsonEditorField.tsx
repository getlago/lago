import { FormikValues } from 'formik'
import _get from 'lodash/get'
import _isEqual from 'lodash/isEqual'
import { memo } from 'react'

import { JsonEditor, JsonEditorProps } from './JsonEditor'

interface JsonEditorFieldProps extends Omit<JsonEditorProps, 'onChange' | 'name'> {
  formikProps: FormikValues
  name: string
  editorMode?: 'text' | 'json'
  validate?: (value: string) => void
  customInvalidError?: string
  showHelperOnError?: boolean
}

export const JsonEditorField = memo(
  ({
    name,
    formikProps,
    editorMode,
    validate,
    customInvalidError,
    showHelperOnError,
    ...props
  }: JsonEditorFieldProps) => {
    const { values, errors, touched, setFieldValue, setFieldError, setFieldTouched } = formikProps

    return (
      <JsonEditor
        name={name}
        value={_get(values, name)}
        error={_get(touched, name) ? (_get(errors, name) as string) : undefined}
        editorMode={editorMode}
        validate={validate}
        showHelperOnError={showHelperOnError}
        customInvalidError={customInvalidError}
        onError={(err) => {
          setFieldError(name, err)
        }}
        onChange={(value: string) => {
          setFieldValue(name, value)
        }}
        onBlur={() => setFieldTouched(name, true, false)}
        {...props}
      />
    )
  },
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

JsonEditorField.displayName = 'JsonEditorField'
