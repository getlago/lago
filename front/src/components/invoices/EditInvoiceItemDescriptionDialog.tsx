import { revalidateLogic } from '@tanstack/react-form'
import { useRef } from 'react'
import { z } from 'zod'

import { useFormDialog } from '~/components/dialogs/FormDialog'
import { DialogResult } from '~/components/dialogs/types'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

const MAX_CHAR_LIMIT = 255

export const EDIT_INVOICE_ITEM_DESCRIPTION_FORM_ID = 'edit-invoice-item-description-form'

type OpenEditInvoiceItemDescriptionDialogParams = {
  description?: string
  callback: (description: string) => void
}

const editInvoiceItemDescriptionValidationSchema = z.object({
  description: z.string().max(MAX_CHAR_LIMIT, { message: 'text_6453819268763979024ad029' }),
})

export const useEditInvoiceItemDescriptionDialog = () => {
  const formDialog = useFormDialog()
  const { translate } = useInternationalization()
  const callbackRef = useRef<((description: string) => void) | null>(null)

  const form = useAppForm({
    defaultValues: {
      description: '',
    },
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: editInvoiceItemDescriptionValidationSchema,
    },
    onSubmit: async ({ value }) => {
      if (value.description) {
        callbackRef.current?.(value.description)
      }
    },
  })

  const handleSubmit = async (): Promise<DialogResult> => {
    await form.handleSubmit()

    // On validation error onSubmit never runs and isSubmitSuccessful stays false:
    // throw to keep the dialog open (closeOnError: false swallows the error, inline
    // field errors stay visible). Returning a result would let FormDialog close it.
    if (!form.state.isSubmitSuccessful) {
      throw new Error('Submit failed')
    }

    return { reason: 'success' }
  }

  const openEditInvoiceItemDescriptionDialog = ({
    description,
    callback,
  }: OpenEditInvoiceItemDescriptionDialogParams) => {
    callbackRef.current = callback
    form.reset()
    form.setFieldValue('description', description ?? '')

    formDialog
      .open({
        title: translate('text_6453819268763979024acff7'),
        description: translate('text_6453819268763979024ad005'),
        cancelOrCloseText: 'cancel',
        children: (
          <div className="p-8">
            <form.AppField name="description">
              {(field) => (
                <field.TextInputField
                  // eslint-disable-next-line jsx-a11y/no-autofocus
                  autoFocus
                  multiline
                  className="whitespace-pre-line"
                  rows="3"
                  label={translate('text_6453819268763979024ad011')}
                  helperText={
                    <div className="flex justify-between gap-2">
                      <div className="flex-1">{translate('text_64539c4583bc9200f203b11d')}</div>
                      <div className="shrink-0">
                        {(field.state.value || '').length}/{MAX_CHAR_LIMIT}
                      </div>
                    </div>
                  }
                />
              )}
            </form.AppField>
          </div>
        ),
        closeOnError: false,
        mainAction: (
          <form.AppForm>
            <form.SubmitButton>{translate('text_6453819268763979024ad041')}</form.SubmitButton>
          </form.AppForm>
        ),
        form: {
          id: EDIT_INVOICE_ITEM_DESCRIPTION_FORM_ID,
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

  return { openEditInvoiceItemDescriptionDialog }
}
