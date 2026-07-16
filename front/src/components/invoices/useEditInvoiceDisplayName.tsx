import { revalidateLogic } from '@tanstack/react-form'
import { useRef } from 'react'
import { z } from 'zod'

import { useFormDialog } from '~/components/dialogs/FormDialog'
import { DialogResult } from '~/components/dialogs/types'
import { InputMaybe } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

type OpenEditInvoiceDisplayNameDialogParams = {
  invoiceDisplayName: InputMaybe<string> | undefined
  callback: (invoiceDisplayName: string) => void
}

export const EDIT_INVOICE_DISPLAY_NAME_FORM_ID = 'edit-invoice-display-name-form'

const editInvoiceDisplayNameValidationSchema = z.object({
  invoiceDisplayName: z.string(),
})

export const useEditInvoiceDisplayNameDialog = () => {
  const formDialog = useFormDialog()
  const { translate } = useInternationalization()
  const callbackRef = useRef<((invoiceDisplayName: string) => void) | null>(null)

  const form = useAppForm({
    defaultValues: {
      invoiceDisplayName: '' as string,
    },
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: editInvoiceDisplayNameValidationSchema,
    },
    onSubmit: async ({ value }) => {
      callbackRef.current?.(value.invoiceDisplayName || '')
    },
  })

  const handleSubmit = async (): Promise<DialogResult> => {
    await form.handleSubmit()

    return { reason: 'success' }
  }

  const openEditInvoiceDisplayNameDialog = ({
    invoiceDisplayName,
    callback,
  }: OpenEditInvoiceDisplayNameDialogParams) => {
    callbackRef.current = callback
    form.reset()
    form.setFieldValue('invoiceDisplayName', invoiceDisplayName ?? '')

    formDialog
      .open({
        title: translate('text_65018c8e5c6b626f030bcf1e'),
        description: translate('text_65018c8e5c6b626f030bcf22'),
        cancelOrCloseText: 'cancel',
        children: (
          <div className="p-8">
            <form.AppField name="invoiceDisplayName">
              {(field) => (
                <field.TextInputField
                  // eslint-disable-next-line jsx-a11y/no-autofocus
                  autoFocus
                  cleanable
                  label={translate('text_65018c8e5c6b626f030bcf26')}
                  placeholder={translate('text_65018c8e5c6b626f030bcf2a')}
                />
              )}
            </form.AppField>
          </div>
        ),
        closeOnError: false,
        mainAction: (
          <form.AppForm>
            <form.SubmitButton>{translate('text_65018c8e5c6b626f030bcf32')}</form.SubmitButton>
          </form.AppForm>
        ),
        form: {
          id: EDIT_INVOICE_DISPLAY_NAME_FORM_ID,
          submit: handleSubmit,
        },
      })
      .then((response) => {
        if (response.reason === 'close') {
          form.reset()
          callbackRef.current = null
        }
      })
  }

  return { openEditInvoiceDisplayNameDialog }
}
