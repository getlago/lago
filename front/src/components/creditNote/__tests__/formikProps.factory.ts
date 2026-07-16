import { FormikProps } from 'formik'

type FormikPropsOverrides<T> = Partial<Omit<FormikProps<T>, 'values'>> & {
  values?: T
}

export const createMockFormikProps = <T = Record<string, unknown>>(
  overrides: FormikPropsOverrides<Partial<T>> = {},
): FormikProps<Partial<T>> => {
  const { values, ...rest } = overrides

  return {
    values: values ?? {},
    errors: {},
    touched: {},
    isSubmitting: false,
    isValidating: false,
    submitCount: 0,
    dirty: false,
    isValid: true,
    initialValues: {},
    initialErrors: {},
    initialTouched: {},
    handleBlur: jest.fn(),
    handleChange: jest.fn(),
    handleReset: jest.fn(),
    handleSubmit: jest.fn(),
    resetForm: jest.fn(),
    setErrors: jest.fn(),
    setFieldError: jest.fn(),
    setFieldTouched: jest.fn(),
    setFieldValue: jest.fn(),
    setFormikState: jest.fn(),
    setStatus: jest.fn(),
    setSubmitting: jest.fn(),
    setTouched: jest.fn(),
    setValues: jest.fn(),
    submitForm: jest.fn(),
    validateForm: jest.fn(),
    validateField: jest.fn(),
    getFieldMeta: jest.fn(),
    getFieldHelpers: jest.fn(),
    getFieldProps: jest.fn(),
    registerField: jest.fn(),
    unregisterField: jest.fn(),
    ...rest,
  }
}
