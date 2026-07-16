import { gql, useApolloClient } from '@apollo/client'
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { addToast, LagoGQLError } from '~/core/apolloClient'
import {
  AllInvoiceDetailsForCustomerInvoiceDetailsFragmentDoc,
  InvoiceForFinalizeInvoiceFragment,
  InvoiceStatusTypeEnum,
  LagoApiError,
  useFinalizeInvoiceMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useFormatterDateHelper } from '~/hooks/helpers/useFormatterDateHelper'

gql`
  fragment InvoiceForFinalizeInvoice on Invoice {
    id
    issuingDate
    customer {
      id
      applicableTimezone
    }
  }

  mutation finalizeInvoice($input: FinalizeInvoiceInput!) {
    finalizeInvoice(input: $input) {
      id
      ...AllInvoiceDetailsForCustomerInvoiceDetails
    }
  }

  ${AllInvoiceDetailsForCustomerInvoiceDetailsFragmentDoc}
`

export interface FinalizeInvoiceDialogRef {
  openDialog: (
    invoice: InvoiceForFinalizeInvoiceFragment | null | undefined,
    callback?: () => void,
  ) => unknown
  closeDialog: () => unknown
}

export const FinalizeInvoiceDialog = forwardRef<FinalizeInvoiceDialogRef>((_, ref) => {
  const { translate } = useInternationalization()
  const { formattedDateWithTimezone } = useFormatterDateHelper()
  const dialogRef = useRef<DialogRef>(null)
  const [invoice, setInvoice] = useState<InvoiceForFinalizeInvoiceFragment>()
  const [callback, setCallback] = useState<(() => void) | null>(null)

  const client = useApolloClient()

  const [finalizeInvoice] = useFinalizeInvoiceMutation({
    variables: { input: { id: invoice?.id || '' } },
    context: {
      silentErrorCodes: [LagoApiError.UnprocessableEntity, LagoApiError.InternalError],
    },
    onCompleted({ finalizeInvoice: finalizeInvoiceRes }) {
      const isClosed = finalizeInvoiceRes?.status === InvoiceStatusTypeEnum.Closed

      client.refetchQueries({
        include: isClosed ? ['getCustomerInvoices'] : ['getCustomerInvoices', 'getInvoiceDetails'],
      })

      if (finalizeInvoiceRes?.id) {
        addToast({
          message: translate('text_63a41b3a01db40c7fff551e1'),
          severity: 'success',
        })
      }

      if (isClosed) {
        callback?.()
      }
    },
    onError: ({ graphQLErrors }) => {
      graphQLErrors.forEach((graphQLError) => {
        const { extensions } = graphQLError as LagoGQLError

        if (extensions.details?.taxError?.length) {
          addToast({
            severity: 'danger',
            translateKey: 'text_1724438705077s7oxv5be87m',
          })
        }
      })
    },
  })

  useImperativeHandle(ref, () => ({
    openDialog: (infos, callbackFn) => {
      !!infos && setInvoice(infos)
      callbackFn && setCallback(() => callbackFn)
      dialogRef.current?.openDialog()
    },
    closeDialog: () => dialogRef.current?.closeDialog(),
  }))

  return (
    <Dialog
      ref={dialogRef}
      title={translate('text_63a4269f72ead1bda4bed106')}
      description={translate('text_63a4269f72ead1bda4bed108', {
        issuingDate: invoice?.issuingDate ? formattedDateWithTimezone(invoice?.issuingDate) : '-',
      })}
      actions={({ closeDialog }) => (
        <>
          <Button
            variant="quaternary"
            onClick={() => {
              closeDialog()
            }}
          >
            {translate('text_63a4269f72ead1bda4bed10a')}
          </Button>
          <Button
            variant="primary"
            onClick={async () => {
              await finalizeInvoice()
              closeDialog()
            }}
          >
            {translate('text_63a4269f72ead1bda4bed10c')}
          </Button>
        </>
      )}
    />
  )
})

FinalizeInvoiceDialog.displayName = 'forwardRef'
