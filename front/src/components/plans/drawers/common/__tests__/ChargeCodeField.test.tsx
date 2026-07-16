import { AnyFieldMeta } from '@tanstack/react-form'
import { act, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { useAppForm } from '~/hooks/forms/useAppform'

import { EXISTING_CODE_ERROR_MESSAGE } from '../chargeCode'
import ChargeCodeField from '../ChargeCodeField'

// Minimal surface the test drives on the host form (the concrete form type isn't
// assignable to useAppForm's unknown-data return type).
type CapturedCodeForm = {
  setFieldMeta: (field: 'code', updater: (meta: AnyFieldMeta) => AnyFieldMeta) => void
  getFieldMeta: (field: 'code') => AnyFieldMeta | undefined
}

let capturedForm: CapturedCodeForm | null = null

const Host = ({ disabled, code = '' }: { disabled?: boolean; code?: string }) => {
  const form = useAppForm({ defaultValues: { code } })

  capturedForm = form as unknown as CapturedCodeForm

  return <ChargeCodeField form={form} fields={{ code: 'code' }} disabled={disabled} />
}

const setCodeError = (message: string) => {
  act(() => {
    capturedForm?.setFieldMeta('code', (meta) => ({
      ...meta,
      errorMap: { ...meta.errorMap, onDynamic: { message } },
    }))
  })
}

const getCodeOnDynamicError = () => {
  const errorMap = capturedForm?.getFieldMeta('code')?.errorMap as
    { onDynamic?: { message?: string } } | undefined

  return errorMap?.onDynamic
}

describe('ChargeCodeField', () => {
  beforeEach(() => {
    capturedForm = null
  })

  it('renders an editable code input by default', () => {
    render(<Host />)

    expect(screen.getByRole('textbox')).not.toBeDisabled()
  })

  it('disables the input when disabled is true', () => {
    render(<Host disabled />)

    expect(screen.getByRole('textbox')).toBeDisabled()
  })

  it('clears the existing-code error once the user edits the code', async () => {
    render(<Host />)

    setCodeError(EXISTING_CODE_ERROR_MESSAGE)
    expect(getCodeOnDynamicError()?.message).toBe(EXISTING_CODE_ERROR_MESSAGE)

    await userEvent.type(screen.getByRole('textbox'), 'x')

    expect(getCodeOnDynamicError()).toBeUndefined()
  })

  it('leaves an unrelated error untouched when the user edits the code', async () => {
    render(<Host />)

    setCodeError('text_some_other_error')

    await userEvent.type(screen.getByRole('textbox'), 'x')

    // Only the duplicate-code message is cleared; other validation errors stay.
    expect(getCodeOnDynamicError()?.message).toBe('text_some_other_error')
  })
})
