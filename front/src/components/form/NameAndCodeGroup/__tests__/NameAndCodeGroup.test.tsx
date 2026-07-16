import { act, cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { useAppForm } from '~/hooks/forms/useAppform'
import { render } from '~/test-utils'

import NameAndCodeGroup from '../NameAndCodeGroup'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

// Ref to access the form instance from tests

let formRef: any = null

// Wrapper component that provides form context
const NameAndCodeGroupWrapper = ({
  disableCodeInput = false,
  disableAutoGenerateCode = false,
  defaultValues = { name: '', code: '' },
  nameProps,
  codeProps,
}: {
  disableCodeInput?: boolean
  disableAutoGenerateCode?: boolean
  defaultValues?: { name: string; code: string }
  nameProps?: Record<string, unknown>
  codeProps?: Record<string, unknown>
}) => {
  const form = useAppForm({
    defaultValues: {
      name: defaultValues.name,
      code: defaultValues.code,
    },
  })

  formRef = form

  return (
    <form.AppForm>
      <form>
        <NameAndCodeGroup
          form={form}
          fields={{ name: 'name', code: 'code' }}
          disableCodeInput={disableCodeInput}
          disableAutoGenerateCode={disableAutoGenerateCode}
          nameProps={nameProps}
          codeProps={codeProps}
        />
      </form>
    </form.AppForm>
  )
}

describe('NameAndCodeGroup', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('Rendering', () => {
    it('renders name input field', async () => {
      await act(() => render(<NameAndCodeGroupWrapper />))

      // Name label translation key
      expect(screen.getByText('text_629728388c4d2300e2d38091')).toBeInTheDocument()
    })

    it('renders code input field', async () => {
      await act(() => render(<NameAndCodeGroupWrapper />))

      // Code label translation key
      expect(screen.getByText('text_629728388c4d2300e2d380b7')).toBeInTheDocument()
    })

    it('renders name placeholder', async () => {
      await act(() => render(<NameAndCodeGroupWrapper />))

      // Name placeholder translation key
      expect(screen.getByPlaceholderText('text_629728388c4d2300e2d380a5')).toBeInTheDocument()
    })

    it('renders code placeholder', async () => {
      await act(() => render(<NameAndCodeGroupWrapper />))

      // Code placeholder translation key
      expect(screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')).toBeInTheDocument()
    })

    it('renders in a grid layout with two columns', async () => {
      const { container } = await act(() => render(<NameAndCodeGroupWrapper />))

      const gridContainer = container.querySelector('.grid.grid-cols-2')

      expect(gridContainer).toBeInTheDocument()
    })
  })

  describe('Default Values', () => {
    it('displays default name value', async () => {
      await act(() =>
        render(<NameAndCodeGroupWrapper defaultValues={{ name: 'Test Name', code: '' }} />),
      )

      const nameInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380a5')

      expect(nameInput).toHaveValue('Test Name')
    })

    it('displays default code value', async () => {
      await act(() =>
        render(<NameAndCodeGroupWrapper defaultValues={{ name: '', code: 'test_code' }} />),
      )

      const codeInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')

      expect(codeInput).toHaveValue('test_code')
    })

    it('displays both default values', async () => {
      await act(() =>
        render(
          <NameAndCodeGroupWrapper defaultValues={{ name: 'Test Name', code: 'test_code' }} />,
        ),
      )

      const nameInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380a5')
      const codeInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')

      expect(nameInput).toHaveValue('Test Name')
      expect(codeInput).toHaveValue('test_code')
    })
  })

  describe('Auto Code Generation', () => {
    it('auto-generates code from name when typing in name field', async () => {
      const user = userEvent.setup()

      await act(() => render(<NameAndCodeGroupWrapper />))

      const nameInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380a5')
      const codeInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')

      await user.type(nameInput, 'My Test Name')

      // Code should be auto-generated from name
      expect(codeInput).toHaveValue('my_test_name')
    })

    it('converts spaces to underscores in auto-generated code', async () => {
      const user = userEvent.setup()

      await act(() => render(<NameAndCodeGroupWrapper />))

      const nameInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380a5')
      const codeInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')

      await user.type(nameInput, 'Name With Spaces')

      expect(codeInput).toHaveValue('name_with_spaces')
    })

    it('converts to lowercase in auto-generated code', async () => {
      const user = userEvent.setup()

      await act(() => render(<NameAndCodeGroupWrapper />))

      const nameInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380a5')
      const codeInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')

      await user.type(nameInput, 'UPPERCASE NAME')

      expect(codeInput).toHaveValue('uppercase_name')
    })
  })

  describe('Code Field Independence', () => {
    it('stops auto-generating code after code field is manually edited', async () => {
      const user = userEvent.setup()

      await act(() => render(<NameAndCodeGroupWrapper />))

      const nameInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380a5')
      const codeInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')

      // First type in name to auto-generate code
      await user.type(nameInput, 'Initial Name')
      expect(codeInput).toHaveValue('initial_name')

      // Now manually edit the code field and blur to lock it
      await user.clear(codeInput)
      await user.type(codeInput, 'custom_code')
      await user.tab() // blur the code field

      // Clear name and type something new
      await user.clear(nameInput)
      await user.type(nameInput, 'New Name')

      // Code should remain as manually entered after blur
      expect(codeInput).toHaveValue('custom_code')
    })
  })

  describe('disableAutoGenerateCode', () => {
    it('does not auto-generate code when disableAutoGenerateCode is true', async () => {
      const user = userEvent.setup()

      await act(() =>
        render(
          <NameAndCodeGroupWrapper
            disableAutoGenerateCode={true}
            defaultValues={{ name: '', code: 'existing_code' }}
          />,
        ),
      )

      const nameInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380a5')
      const codeInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')

      await user.type(nameInput, 'New Name')

      expect(codeInput).toHaveValue('existing_code')
    })

    it('keeps code input enabled when disableAutoGenerateCode is true', async () => {
      await act(() => render(<NameAndCodeGroupWrapper disableAutoGenerateCode={true} />))

      const codeInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')

      expect(codeInput).not.toBeDisabled()
    })

    it('allows manual code edits when disableAutoGenerateCode is true', async () => {
      const user = userEvent.setup()

      await act(() => render(<NameAndCodeGroupWrapper disableAutoGenerateCode={true} />))

      const codeInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')

      await user.type(codeInput, 'manual_code')

      expect(codeInput).toHaveValue('manual_code')
    })
  })

  describe('Disabled State', () => {
    it('disables code input when disableCodeInput is true', async () => {
      await act(() => render(<NameAndCodeGroupWrapper disableCodeInput={true} />))

      const codeInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')

      expect(codeInput).toBeDisabled()
    })

    it('does not auto-generate code when disableCodeInput is true', async () => {
      const user = userEvent.setup()

      await act(() =>
        render(
          <NameAndCodeGroupWrapper
            disableCodeInput={true}
            defaultValues={{ name: '', code: 'existing_code' }}
          />,
        ),
      )

      const nameInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380a5')
      const codeInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')

      await user.type(nameInput, 'New Name')

      // Code should not change when disabled
      expect(codeInput).toHaveValue('existing_code')
    })
  })

  describe('User Interaction', () => {
    it('allows typing in name field', async () => {
      const user = userEvent.setup()

      await act(() => render(<NameAndCodeGroupWrapper />))

      const nameInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380a5')

      await user.type(nameInput, 'Test typing')

      expect(nameInput).toHaveValue('Test typing')
    })

    it('allows typing in code field when not disabled', async () => {
      const user = userEvent.setup()

      await act(() => render(<NameAndCodeGroupWrapper />))

      const codeInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380d9')

      await user.type(codeInput, 'test_code')

      expect(codeInput).toHaveValue('test_code')
    })

    it('allows clearing name field', async () => {
      const user = userEvent.setup()

      await act(() =>
        render(<NameAndCodeGroupWrapper defaultValues={{ name: 'Initial Name', code: '' }} />),
      )

      const nameInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380a5')

      await user.clear(nameInput)

      expect(nameInput).toHaveValue('')
    })
  })

  describe('nameProps and codeProps', () => {
    it('passes nameProps through to the name TextInputField', async () => {
      await act(() => render(<NameAndCodeGroupWrapper nameProps={{ autoFocus: true }} />))

      const nameInput = screen.getByPlaceholderText('text_629728388c4d2300e2d380a5')

      expect(nameInput).toHaveFocus()
    })

    it('passes codeProps through to the code TextInputField', async () => {
      await act(() =>
        render(<NameAndCodeGroupWrapper codeProps={{ placeholder: 'custom-placeholder' }} />),
      )

      expect(screen.getByPlaceholderText('custom-placeholder')).toBeInTheDocument()
    })
  })

  describe('Server-side error propagation', () => {
    it('displays error under code input when setFieldMeta sets onDynamic error', async () => {
      await act(() => render(<NameAndCodeGroupWrapper />))

      // Simulate server-side "code already exists" error via setFieldMeta
      await act(() => {
        formRef.setFieldMeta('code', (meta: Record<string, unknown>) => ({
          ...meta,
          errorMap: {
            ...(meta.errorMap as Record<string, unknown>),
            onDynamic: { message: 'text_632a2d437e341dcc76817556' },
          },
        }))
      })

      // The error should be displayed (translated by the mock as the key itself)
      expect(screen.getByText('text_632a2d437e341dcc76817556')).toBeInTheDocument()
    })
  })
})
