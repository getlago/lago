import { gql } from '@apollo/client'
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'

import { PaymentMethodComboBox } from '~/components/paymentMethodSelection/PaymentMethodComboBox'
import { SelectedPaymentMethod } from '~/components/paymentMethodSelection/types'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import {
  InvoiceForResendInvoiceForCollectionDialogFragment,
  LagoApiError,
  useRetryInvoicePaymentMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { Button } from '../designSystem/Button'
import { Dialog, DialogRef } from '../designSystem/Dialog'
import { Typography } from '../designSystem/Typography'

export const RESEND_INVOICE_FOR_COLLECTION_DIALOG_CANCEL_BUTTON_TEST_ID =
  'resend-invoice-for-collection-dialog-cancel-button'
export const RESEND_INVOICE_FOR_COLLECTION_DIALOG_SUBMIT_BUTTON_TEST_ID =
  'resend-invoice-for-collection-dialog-submit-button'

gql`
  fragment InvoiceForResendInvoiceForCollectionDialog on Invoice {
    id
    number
    customer {
      id
      externalId
    }
  }
`

type ResendInvoiceForCollectionDialogProps = {
  invoice?: InvoiceForResendInvoiceForCollectionDialogFragment | null
  preselectedPaymentMethodId?: string | null
}

export interface ResendInvoiceForCollectionDialogRef {
  openDialog: (dialogData: ResendInvoiceForCollectionDialogProps) => unknown
  closeDialog: () => unknown
}

export const ResendInvoiceForCollectionDialog = forwardRef<ResendInvoiceForCollectionDialogRef>(
  (_, ref) => {
    const dialogRef = useRef<DialogRef>(null)
    const { translate } = useInternationalization()
    const [dialogData, setDialogData] = useState<ResendInvoiceForCollectionDialogProps | undefined>(
      undefined,
    )
    const [selectedPaymentMethod, setSelectedPaymentMethod] = useState<SelectedPaymentMethod>(null)

    const invoice = dialogData?.invoice

    const [retryInvoicePayment, { loading }] = useRetryInvoicePaymentMutation({
      context: { silentErrorCodes: [LagoApiError.PaymentProcessorIsCurrentlyHandlingPayment] },
      onCompleted({ retryInvoicePayment: data }) {
        if (data?.id) {
          addToast({
            severity: 'success',
            translateKey: 'text_63ac86d897f728a87b2fa0b3',
          })
        }
      },
    })

    useImperativeHandle(ref, () => ({
      openDialog: (data) => {
        setDialogData(data)
        setSelectedPaymentMethod(
          data.preselectedPaymentMethodId
            ? { paymentMethodId: data.preselectedPaymentMethodId }
            : null,
        )
        dialogRef.current?.openDialog()
      },
      closeDialog: () => dialogRef.current?.closeDialog(),
    }))

    const handleSubmit = async () => {
      const { errors } = await retryInvoicePayment({
        variables: {
          input: {
            id: invoice?.id as string,
            ...(selectedPaymentMethod && {
              paymentMethod: {
                paymentMethodId: selectedPaymentMethod.paymentMethodId,
                paymentMethodType: selectedPaymentMethod.paymentMethodType,
              },
            }),
          },
        },
      })

      if (hasDefinedGQLError('PaymentProcessorIsCurrentlyHandlingPayment', errors)) {
        addToast({
          severity: 'info',
          translateKey: 'text_63b6d06df1a53b7e2ad973ad',
        })
      }

      dialogRef.current?.closeDialog()
    }

    return (
      <Dialog
        ref={dialogRef}
        title={translate('text_17683906296679tuqxj77ou9')}
        description={translate('text_1768390629667tvmfcdlro8l', {
          invoiceNumber: invoice?.number,
        })}
        onClose={() => {
          setDialogData(undefined)
          setSelectedPaymentMethod(null)
        }}
        actions={({ closeDialog }) => (
          <>
            <Button
              variant="quaternary"
              onClick={closeDialog}
              data-test={RESEND_INVOICE_FOR_COLLECTION_DIALOG_CANCEL_BUTTON_TEST_ID}
            >
              {translate('text_6411e6b530cb47007488b027')}
            </Button>
            <Button
              onClick={handleSubmit}
              disabled={loading || !selectedPaymentMethod?.paymentMethodId}
              data-test={RESEND_INVOICE_FOR_COLLECTION_DIALOG_SUBMIT_BUTTON_TEST_ID}
            >
              {translate('text_63ac86d897f728a87b2fa039')}
            </Button>
          </>
        )}
      >
        <div className="mb-8">
          <Typography variant="captionHl" color="textSecondary" className="mb-1">
            {translate('text_17440371192353kif37ol194')}
          </Typography>
          <PaymentMethodComboBox
            externalCustomerId={invoice?.customer?.externalId}
            selectedPaymentMethod={selectedPaymentMethod}
            setSelectedPaymentMethod={setSelectedPaymentMethod}
            PopperProps={{ displayInDialog: true }}
          />
        </div>
      </Dialog>
    )
  },
)

ResendInvoiceForCollectionDialog.displayName = 'ResendInvoiceForCollectionDialog'
