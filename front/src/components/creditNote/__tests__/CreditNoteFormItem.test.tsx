import { render, screen } from '@testing-library/react'

import { CurrencyEnum } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { CreditNoteFormItem } from '../CreditNoteFormItem'

const createMockFormikProps = (overrides: Record<string, unknown> = {}) => ({
  values: {
    testFee: { checked: true, value: 100 },
  },
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
  initialStatus: undefined,
  status: undefined,
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
  validateField: jest.fn(),
  validateForm: jest.fn(),
  getFieldProps: jest.fn(),
  getFieldMeta: jest.fn(),
  getFieldHelpers: jest.fn(),
  registerField: jest.fn(),
  unregisterField: jest.fn(),
  ...overrides,
})

const defaultProps = {
  currency: CurrencyEnum.Usd,
  feeName: 'Test Fee',
  formikKey: 'testFee',
  maxValue: 10000,
}

const renderComponent = (
  props: Partial<typeof defaultProps & { isReadOnly?: boolean }> = {},
  formikOverrides: Record<string, unknown> = {},
) => {
  const formikProps = createMockFormikProps(formikOverrides)

  return render(
    <CreditNoteFormItem
      {...defaultProps}
      {...props}
      formikProps={formikProps as Parameters<typeof CreditNoteFormItem>[0]['formikProps']}
    />,
    {
      wrapper: AllTheProviders,
    },
  )
}

describe('CreditNoteFormItem', () => {
  describe('isReadOnly prop', () => {
    it('should disable the input when isReadOnly is true', () => {
      renderComponent({ isReadOnly: true })

      const input = screen.getByRole('textbox')

      expect(input).toBeDisabled()
    })

    it('should enable the input when isReadOnly is false and checkbox is checked', () => {
      renderComponent({ isReadOnly: false })

      const input = screen.getByRole('textbox')

      expect(input).not.toBeDisabled()
    })

    it('should enable the input when isReadOnly is undefined and checkbox is checked', () => {
      renderComponent({ isReadOnly: undefined })

      const input = screen.getByRole('textbox')

      expect(input).not.toBeDisabled()
    })

    it('should disable the input when checkbox is unchecked regardless of isReadOnly', () => {
      renderComponent(
        { isReadOnly: false },
        {
          values: {
            testFee: { checked: false, value: 100 },
          },
        },
      )

      const input = screen.getByRole('textbox')

      expect(input).toBeDisabled()
    })
  })
})
