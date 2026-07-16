import { gql } from '@apollo/client'
import { revalidateLogic } from '@tanstack/react-form'
import { useRef } from 'react'
import { z } from 'zod'

import { useFormDialog } from '~/components/dialogs/FormDialog'
import { DialogResult } from '~/components/dialogs/types'
import { addToast } from '~/core/apolloClient'
import {
  AllInvoiceDetailsForCustomerInvoiceDetailsFragmentDoc,
  InvoiceForUpdateInvoicePaymentStatusFragment,
  InvoiceListItemFragmentDoc,
  InvoicePaymentStatusTypeEnum,
  useUpdateInvoicePaymentStatusMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

gql`
  fragment InvoiceForUpdateInvoicePaymentStatus on Invoice {
    id
    paymentStatus
  }

  mutation updateInvoicePaymentStatus($input: UpdateInvoiceInput!) {
    updateInvoice(input: $input) {
      id
      ...InvoiceForUpdateInvoicePaymentStatus
      ...InvoiceListItem
      ...AllInvoiceDetailsForCustomerInvoiceDetails
    }
  }

  ${AllInvoiceDetailsForCustomerInvoiceDetailsFragmentDoc}
  ${InvoiceListItemFragmentDoc}
`

export const UPDATE_INVOICE_PAYMENT_STATUS_FORM_ID = 'update-invoice-payment-status-form'

const updateInvoicePaymentStatusValidationSchema = z.object({
  paymentStatus: z
    .string({ message: 'text_624ea7c29103fd010732ab7d' })
    .min(1, { message: 'text_624ea7c29103fd010732ab7d' }),
})

export const useUpdateInvoicePaymentStatusDialog = () => {
  const formDialog = useFormDialog()
  const { translate } = useInternationalization()
  const invoiceRef = useRef<InvoiceForUpdateInvoicePaymentStatusFragment | null>(null)
  const successRef = useRef(false)

  const [updateInvoice] = useUpdateInvoicePaymentStatusMutation({
    onCompleted({ updateInvoice: updateInvoiceRes }) {
      if (updateInvoiceRes?.id) {
        addToast({
          message: translate('text_63eba8c65a6c8043feee2a02'),
          severity: 'success',
        })
      }
    },
  })

  const form = useAppForm({
    defaultValues: {
      paymentStatus: '' as string,
    },
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: updateInvoicePaymentStatusValidationSchema,
    },
    onSubmit: async ({ value }) => {
      const invoice = invoiceRef.current

      if (!invoice?.id) {
        return
      }

      const res = await updateInvoice({
        variables: {
          input: {
            id: invoice.id,
            paymentStatus: value.paymentStatus as InvoicePaymentStatusTypeEnum,
          },
        },
      })

      if (res.data?.updateInvoice) {
        successRef.current = true
      }
    },
  })

  const handleSubmit = async (): Promise<DialogResult> => {
    successRef.current = false
    await form.handleSubmit()

    if (!successRef.current) {
      throw new Error('Submit failed')
    }

    return { reason: 'success' }
  }

  const openUpdateInvoicePaymentStatusDialog = (
    invoice: InvoiceForUpdateInvoicePaymentStatusFragment,
  ) => {
    invoiceRef.current = invoice
    form.reset()
    form.setFieldValue('paymentStatus', invoice.paymentStatus ?? '')

    formDialog
      .open({
        title: translate('text_63eba8c65a6c8043feee2a0d'),
        description: translate('text_63eba8c65a6c8043feee2a0e'),
        cancelOrCloseText: 'cancel',
        children: (
          <div className="p-8">
            <form.AppField name="paymentStatus">
              {(field) => (
                <field.ComboBoxField
                  disableClearable
                  label={translate('text_63eba8c65a6c8043feee2a0f')}
                  data={Object.values(InvoicePaymentStatusTypeEnum).map((status) => ({
                    label: status.charAt(0).toUpperCase() + status.slice(1),
                    value: status,
                  }))}
                  PopperProps={{ displayInDialog: true }}
                />
              )}
            </form.AppField>
          </div>
        ),
        closeOnError: false,
        mainAction: (
          <form.AppForm>
            <form.SubmitButton>{translate('text_63eba8c65a6c8043feee2a15')}</form.SubmitButton>
          </form.AppForm>
        ),
        form: {
          id: UPDATE_INVOICE_PAYMENT_STATUS_FORM_ID,
          submit: handleSubmit,
        },
      })
      .then((response) => {
        if (response.reason === 'close') {
          form.reset()
          invoiceRef.current = null
        }
      })
  }

  return { openUpdateInvoicePaymentStatusDialog }
}
