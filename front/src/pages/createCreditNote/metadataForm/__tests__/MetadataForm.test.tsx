import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { FormikProps } from 'formik'

import { render } from '~/test-utils'

import MetadataForm, { META_DATA_BUTTON_DATA_TEST_ID } from '../MetadataForm'

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

describe('MetadataForm', () => {
  afterEach(cleanup)

  describe('rendering', () => {
    it('renders add metadata button when metadata is empty', async () => {
      const formikProps = createMockFormikProps({ metadata: [] })

      await act(() => render(<MetadataForm formikProps={formikProps} />))

      expect(screen.getByTestId(META_DATA_BUTTON_DATA_TEST_ID)).toBeInTheDocument()
      expect(screen.getByTestId(META_DATA_BUTTON_DATA_TEST_ID)).not.toBeDisabled()
    })

    it('renders metadata fields when metadata exists', async () => {
      const formikProps = createMockFormikProps({
        metadata: [{ key: 'testKey', value: 'testValue', localId: '123' }],
      })

      await act(() => render(<MetadataForm formikProps={formikProps} />))

      expect(screen.getByDisplayValue('testKey')).toBeInTheDocument()
      expect(screen.getByDisplayValue('testValue')).toBeInTheDocument()
    })

    it('renders multiple metadata items', async () => {
      const formikProps = createMockFormikProps({
        metadata: [
          { key: 'key1', value: 'value1', localId: '1' },
          { key: 'key2', value: 'value2', localId: '2' },
          { key: 'key3', value: 'value3', localId: '3' },
        ],
      })

      await act(() => render(<MetadataForm formikProps={formikProps} />))

      expect(screen.getByDisplayValue('key1')).toBeInTheDocument()
      expect(screen.getByDisplayValue('value1')).toBeInTheDocument()
      expect(screen.getByDisplayValue('key2')).toBeInTheDocument()
      expect(screen.getByDisplayValue('value2')).toBeInTheDocument()
      expect(screen.getByDisplayValue('key3')).toBeInTheDocument()
      expect(screen.getByDisplayValue('value3')).toBeInTheDocument()
    })
  })

  describe('add metadata', () => {
    it('calls setFieldValue when add button is clicked', async () => {
      const formikProps = createMockFormikProps({ metadata: [] })

      await act(() => render(<MetadataForm formikProps={formikProps} />))

      await waitFor(() => userEvent.click(screen.getByTestId(META_DATA_BUTTON_DATA_TEST_ID)))

      expect(formikProps.setFieldValue).toHaveBeenCalledWith(
        'metadata',
        expect.arrayContaining([
          expect.objectContaining({
            key: '',
            value: '',
            localId: expect.any(String),
          }),
        ]),
      )
    })

    it('appends to existing metadata when add button is clicked', async () => {
      const existingMetadata = [{ key: 'existing', value: 'data', localId: '123' }]
      const formikProps = createMockFormikProps({ metadata: existingMetadata })

      await act(() => render(<MetadataForm formikProps={formikProps} />))

      await waitFor(() => userEvent.click(screen.getByTestId(META_DATA_BUTTON_DATA_TEST_ID)))

      expect(formikProps.setFieldValue).toHaveBeenCalledWith(
        'metadata',
        expect.arrayContaining([
          existingMetadata[0],
          expect.objectContaining({
            key: '',
            value: '',
            localId: expect.any(String),
          }),
        ]),
      )
    })
  })

  describe('remove metadata', () => {
    it('calls setFieldValue to remove metadata item when trash button is clicked', async () => {
      const formikProps = createMockFormikProps({
        metadata: [
          { key: 'key1', value: 'value1', localId: '1' },
          { key: 'key2', value: 'value2', localId: '2' },
        ],
      })

      await act(() => render(<MetadataForm formikProps={formikProps} />))

      // Get all buttons - the last one is "add", the rest are trash buttons for each metadata item
      const allButtons = screen.getAllByTestId('button')
      const trashButtons = allButtons.slice(0, -1)

      await waitFor(() => userEvent.click(trashButtons[0]))

      expect(formikProps.setFieldValue).toHaveBeenCalledWith('metadata', [
        { key: 'key2', value: 'value2', localId: '2' },
      ])
    })

    it('removes correct item when middle item trash is clicked', async () => {
      const formikProps = createMockFormikProps({
        metadata: [
          { key: 'key1', value: 'value1', localId: '1' },
          { key: 'key2', value: 'value2', localId: '2' },
          { key: 'key3', value: 'value3', localId: '3' },
        ],
      })

      await act(() => render(<MetadataForm formikProps={formikProps} />))

      // Get all buttons - the last one is "add", the rest are trash buttons for each metadata item
      const allButtons = screen.getAllByTestId('button')
      const trashButtons = allButtons.slice(0, -1)

      await waitFor(() => userEvent.click(trashButtons[1]))

      expect(formikProps.setFieldValue).toHaveBeenCalledWith('metadata', [
        { key: 'key1', value: 'value1', localId: '1' },
        { key: 'key3', value: 'value3', localId: '3' },
      ])
    })
  })

  describe('max metadata count', () => {
    it('disables add button when default max count (50) is reached', async () => {
      const metadata = Array.from({ length: 50 }, (_, i) => ({
        key: `key${i}`,
        value: `value${i}`,
        localId: `${i}`,
      }))
      const formikProps = createMockFormikProps({ metadata })

      await act(() => render(<MetadataForm formikProps={formikProps} />))

      expect(screen.getByTestId(META_DATA_BUTTON_DATA_TEST_ID)).toBeDisabled()
    })

    it('disables add button when custom max count is reached', async () => {
      const metadata = Array.from({ length: 3 }, (_, i) => ({
        key: `key${i}`,
        value: `value${i}`,
        localId: `${i}`,
      }))
      const formikProps = createMockFormikProps({ metadata })

      await act(() => render(<MetadataForm formikProps={formikProps} maxMetadataCount={3} />))

      expect(screen.getByTestId(META_DATA_BUTTON_DATA_TEST_ID)).toBeDisabled()
    })

    it('enables add button when below max count', async () => {
      const metadata = Array.from({ length: 2 }, (_, i) => ({
        key: `key${i}`,
        value: `value${i}`,
        localId: `${i}`,
      }))
      const formikProps = createMockFormikProps({ metadata })

      await act(() => render(<MetadataForm formikProps={formikProps} maxMetadataCount={3} />))

      expect(screen.getByTestId(META_DATA_BUTTON_DATA_TEST_ID)).not.toBeDisabled()
    })
  })

  describe('edge cases', () => {
    it('handles undefined metadata gracefully', async () => {
      const formikProps = createMockFormikProps({ metadata: undefined })

      await act(() => render(<MetadataForm formikProps={formikProps} />))

      expect(screen.getByTestId(META_DATA_BUTTON_DATA_TEST_ID)).toBeInTheDocument()
    })

    it('handles metadata without localId', async () => {
      const formikProps = createMockFormikProps({
        metadata: [{ key: 'key1', value: 'value1' }],
      })

      await act(() => render(<MetadataForm formikProps={formikProps} />))

      expect(screen.getByDisplayValue('key1')).toBeInTheDocument()
      expect(screen.getByDisplayValue('value1')).toBeInTheDocument()
    })
  })

  describe('snapshots', () => {
    it('matches snapshot with empty metadata', async () => {
      const formikProps = createMockFormikProps({ metadata: [] })

      const { container } = await act(() => render(<MetadataForm formikProps={formikProps} />))

      expect(container).toMatchSnapshot()
    })

    it('matches snapshot with disabled add button at max count', async () => {
      const metadata = Array.from({ length: 5 }, (_, i) => ({
        key: `key${i}`,
        value: `value${i}`,
        localId: `snapshot-${i}`,
      }))
      const formikProps = createMockFormikProps({ metadata })

      const { container } = await act(() =>
        render(<MetadataForm formikProps={formikProps} maxMetadataCount={5} />),
      )

      expect(container).toMatchSnapshot()
    })
  })
})
