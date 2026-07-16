import { act, cleanup, screen } from '@testing-library/react'
import { FormikProps } from 'formik'

import { render } from '~/test-utils'

import { META_DATA_BUTTON_DATA_TEST_ID } from '../MetadataForm'
import MetadataFormCard from '../MetadataFormCard'

type FormValues = {
  metadata?: Array<{
    key: string
    value: string
    localId?: string
  }>
}

const createMockFormikProps = (values: FormValues): FormikProps<FormValues> => ({
  values,
  errors: {},
  touched: {},
  isSubmitting: false,
  isValidating: false,
  submitCount: 0,
  dirty: false,
  isValid: true,
  initialValues: values,
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
  getFieldMeta: jest.fn(),
  getFieldHelpers: jest.fn(),
  getFieldProps: jest.fn(),
  registerField: jest.fn(),
  unregisterField: jest.fn(),
})

describe('MetadataFormCard', () => {
  afterEach(cleanup)

  describe('rendering', () => {
    it('renders the card with title and description', async () => {
      const formikProps = createMockFormikProps({ metadata: [] })

      await act(() => render(<MetadataFormCard formikProps={formikProps} />))

      // Check that translated text elements are present
      expect(screen.getByText('Metadata')).toBeInTheDocument()
    })

    it('renders MetadataForm inside the card', async () => {
      const formikProps = createMockFormikProps({ metadata: [] })

      await act(() => render(<MetadataFormCard formikProps={formikProps} />))

      // MetadataForm renders the add button
      expect(screen.getByTestId(META_DATA_BUTTON_DATA_TEST_ID)).toBeInTheDocument()
    })

    it('passes formikProps to MetadataForm correctly', async () => {
      const formikProps = createMockFormikProps({
        metadata: [{ key: 'testKey', value: 'testValue', localId: '123' }],
      })

      await act(() => render(<MetadataFormCard formikProps={formikProps} />))

      // MetadataForm should display the metadata from formikProps
      expect(screen.getByDisplayValue('testKey')).toBeInTheDocument()
      expect(screen.getByDisplayValue('testValue')).toBeInTheDocument()
    })

    it('renders multiple metadata items through MetadataForm', async () => {
      const formikProps = createMockFormikProps({
        metadata: [
          { key: 'key1', value: 'value1', localId: '1' },
          { key: 'key2', value: 'value2', localId: '2' },
        ],
      })

      await act(() => render(<MetadataFormCard formikProps={formikProps} />))

      expect(screen.getByDisplayValue('key1')).toBeInTheDocument()
      expect(screen.getByDisplayValue('value1')).toBeInTheDocument()
      expect(screen.getByDisplayValue('key2')).toBeInTheDocument()
      expect(screen.getByDisplayValue('value2')).toBeInTheDocument()
    })
  })

  describe('snapshots', () => {
    it('matches snapshot with empty metadata', async () => {
      const formikProps = createMockFormikProps({ metadata: [] })

      const { container } = await act(() => render(<MetadataFormCard formikProps={formikProps} />))

      expect(container).toMatchSnapshot()
    })

    it('matches snapshot with metadata items', async () => {
      const formikProps = createMockFormikProps({
        metadata: [
          { key: 'environment', value: 'production', localId: 'snapshot-1' },
          { key: 'version', value: '1.0.0', localId: 'snapshot-2' },
        ],
      })

      const { container } = await act(() => render(<MetadataFormCard formikProps={formikProps} />))

      expect(container).toMatchSnapshot()
    })
  })
})
