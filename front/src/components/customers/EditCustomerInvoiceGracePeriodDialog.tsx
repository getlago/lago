import { gql } from '@apollo/client'
import InputAdornment from '@mui/material/InputAdornment'
import { revalidateLogic, useStore } from '@tanstack/react-form'
import { forwardRef, useRef } from 'react'
import { useParams } from 'react-router-dom'
import { z } from 'zod'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { addToast } from '~/core/apolloClient'
import { useUpdateCustomerInvoiceGracePeriodMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

gql`
  fragment EditCustomerInvoiceGracePeriod on Customer {
    id
    invoiceGracePeriod
  }

  mutation updateCustomerInvoiceGracePeriod($input: UpdateCustomerInvoiceGracePeriodInput!) {
    updateCustomerInvoiceGracePeriod(input: $input) {
      id
      ...EditCustomerInvoiceGracePeriod
    }
  }
`

const editCustomerInvoiceGracePeriodValidationSchema = z.object({
  invoiceGracePeriod: z
    .union([z.number().max(365, { message: 'text_63bed78ae69de9cad5c348e4' }), z.literal('')])
    .refine((val) => val !== '', { message: 'text_177583191144596sed2y63wo' }),
})

export type EditCustomerInvoiceGracePeriodDialogRef = DialogRef

interface EditCustomerInvoiceGracePeriodDialogProps {
  invoiceGracePeriod: number | undefined | null
}

export const EditCustomerInvoiceGracePeriodDialog = forwardRef<
  DialogRef,
  EditCustomerInvoiceGracePeriodDialogProps
>(({ invoiceGracePeriod }: EditCustomerInvoiceGracePeriodDialogProps, ref) => {
  const { customerId } = useParams()
  const { translate } = useInternationalization()
  const closeDialogRef = useRef<(() => void) | null>(null)
  const [updateCustomerInvoiceGracePeriod] = useUpdateCustomerInvoiceGracePeriodMutation({
    onCompleted(res) {
      if (res?.updateCustomerInvoiceGracePeriod) {
        addToast({
          severity: 'success',
          translateKey: 'text_638dff9779fb99299bee914a',
        })
      }
    },
  })

  const form = useAppForm({
    defaultValues: {
      invoiceGracePeriod: (invoiceGracePeriod ?? '') as number | '',
    },
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: editCustomerInvoiceGracePeriodValidationSchema,
    },
    onSubmit: async ({ value }) => {
      await updateCustomerInvoiceGracePeriod({
        variables: {
          input: {
            id: customerId || '',
            invoiceGracePeriod: Number(value.invoiceGracePeriod) || 0,
          },
        },
      })
      closeDialogRef.current?.()
    },
  })

  const isDirty = useStore(form.store, (state) => state.isDirty)
  const canSubmit = useStore(form.store, (state) => state.canSubmit)

  return (
    <Dialog
      ref={ref}
      title={translate('text_638dff9779fb99299bee90b0')}
      description={translate('text_638dff9779fb99299bee90b4')}
      onClose={() => form.reset()}
      actions={({ closeDialog }) => (
        <>
          <Button variant="quaternary" onClick={closeDialog}>
            {translate('text_638dff9779fb99299bee90c8')}
          </Button>
          <Button
            variant="primary"
            disabled={!canSubmit || !isDirty}
            onClick={async () => {
              closeDialogRef.current = closeDialog
              await form.handleSubmit()
            }}
          >
            {translate('text_638dff9779fb99299bee90cc')}
          </Button>
        </>
      )}
    >
      <div className="mb-8">
        <form.AppField name="invoiceGracePeriod">
          {(field) => (
            <field.TextInputField
              beforeChangeFormatter={['positiveNumber', 'int']}
              label={translate('text_638dff9779fb99299bee90bc')}
              placeholder={translate('text_638dff9779fb99299bee90c0')}
              InputProps={{
                endAdornment: (
                  <InputAdornment position="end">
                    {translate('text_638dff9779fb99299bee90c4')}
                  </InputAdornment>
                ),
              }}
            />
          )}
        </form.AppField>
      </div>
    </Dialog>
  )
})

EditCustomerInvoiceGracePeriodDialog.displayName = 'EditCustomerInvoiceGracePeriodDialog'
