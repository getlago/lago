import { revalidateLogic } from '@tanstack/react-form'
import { useId, useRef } from 'react'
import { z } from 'zod'

import { useFormDialog } from '~/components/dialogs/FormDialog'
import { DialogResult } from '~/components/dialogs/types'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

import {
  PURCHASE_ORDER_NUMBER_FIELD,
  PURCHASE_ORDER_NUMBER_MAX_LENGTH,
  PURCHASE_ORDER_TRANSLATIONS,
} from './constants'
import { PurchaseOrderRootProps } from './types'
import { normalizePurchaseOrderNumber } from './utils'

export const PURCHASE_ORDER_DIALOG_SUBMIT_BUTTON_TEST_ID = 'purchase-order-dialog-submit-button'

const purchaseOrderNumberSchema = z.object({
  purchaseOrderNumber: z.string().max(PURCHASE_ORDER_NUMBER_MAX_LENGTH, {
    message: PURCHASE_ORDER_TRANSLATIONS.maxLength,
  }),
})

type UsePurchaseOrderNumberDialogsParams = Pick<
  PurchaseOrderRootProps,
  'description' | 'onChange' | 'value'
>

export const usePurchaseOrderNumberDialogs = ({
  description,
  onChange,
  value,
}: UsePurchaseOrderNumberDialogsParams) => {
  const { translate } = useInternationalization()
  const formDialog = useFormDialog()
  const id = useId()
  const submitSucceededRef = useRef(false)

  const form = useAppForm({
    defaultValues: { purchaseOrderNumber: value || '' },
    validationLogic: revalidateLogic(),
    validators: { onDynamic: purchaseOrderNumberSchema },
    onSubmit: async ({ value: formValue }) => {
      await onChange?.(normalizePurchaseOrderNumber(formValue.purchaseOrderNumber))
      submitSucceededRef.current = true
    },
  })

  const handleSubmit = async (): Promise<DialogResult> => {
    submitSucceededRef.current = false
    await form.handleSubmit()

    if (!submitSucceededRef.current) {
      throw new Error('Purchase order number form submission failed')
    }

    return { reason: 'success' }
  }

  const openEditDialog = () => {
    form.reset({ purchaseOrderNumber: value || '' }, { keepDefaultValues: true })

    formDialog.open({
      title: translate(PURCHASE_ORDER_TRANSLATIONS.title),
      description: description || translate(PURCHASE_ORDER_TRANSLATIONS.dialogDescription),
      cancelOrCloseText: 'cancel',
      children: (
        <div className="p-8">
          <form.AppField name={PURCHASE_ORDER_NUMBER_FIELD}>
            {(field) => (
              <field.TextInputField
                label={translate(PURCHASE_ORDER_TRANSLATIONS.title)}
                placeholder={translate(PURCHASE_ORDER_TRANSLATIONS.placeholder)}
              />
            )}
          </form.AppField>
        </div>
      ),
      closeOnError: false,
      mainAction: (
        <form.AppForm>
          <form.SubmitButton dataTest={PURCHASE_ORDER_DIALOG_SUBMIT_BUTTON_TEST_ID}>
            {translate('text_17295436903260tlyb1gp1i7')}
          </form.SubmitButton>
        </form.AppForm>
      ),
      form: {
        id: `purchase-order-number-form-${id}`,
        submit: handleSubmit,
      },
    })
  }

  return {
    openEditDialog,
  }
}
