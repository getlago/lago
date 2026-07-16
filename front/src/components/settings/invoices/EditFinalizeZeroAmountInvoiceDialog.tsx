import { gql } from '@apollo/client'
import { useFormik } from 'formik'
import { forwardRef } from 'react'
import { object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { ComboBoxField } from '~/components/form'
import { addToast } from '~/core/apolloClient'
import {
  EditBillingEntityFinalizeZeroAmountInvoiceForDialogFragment,
  EditCustomerFinalizeZeroAmountInvoiceForDialogFragment,
  FinalizeZeroAmountInvoiceEnum,
  useUpdateBillingEntityFinalizeZeroAmountInvoiceMutation,
  useUpdateCustomerFinalizeZeroAmountInvoiceMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment EditCustomerFinalizeZeroAmountInvoiceForDialog on Customer {
    id
    externalId
    name
    finalizeZeroAmountInvoice
  }

  fragment EditBillingEntityFinalizeZeroAmountInvoiceForDialog on BillingEntity {
    id
    finalizeZeroAmountInvoice
  }

  mutation updateCustomerFinalizeZeroAmountInvoice($input: UpdateCustomerInput!) {
    updateCustomer(input: $input) {
      id
      ...EditCustomerFinalizeZeroAmountInvoiceForDialog
    }
  }

  mutation updateBillingEntityFinalizeZeroAmountInvoice($input: UpdateBillingEntityInput!) {
    updateBillingEntity(input: $input) {
      id
      ...EditBillingEntityFinalizeZeroAmountInvoiceForDialog
    }
  }
`

type EditFinalizeZeroAmountInvoiceDialogProps = {
  entity?:
    | EditCustomerFinalizeZeroAmountInvoiceForDialogFragment
    | EditBillingEntityFinalizeZeroAmountInvoiceForDialogFragment
    | null
  finalizeZeroAmountInvoice?: FinalizeZeroAmountInvoiceEnum | boolean | null
}

export type EditFinalizeZeroAmountInvoiceDialogRef = DialogRef

export const EditFinalizeZeroAmountInvoiceDialog = forwardRef<
  EditFinalizeZeroAmountInvoiceDialogRef,
  EditFinalizeZeroAmountInvoiceDialogProps
>(({ entity, finalizeZeroAmountInvoice }: EditFinalizeZeroAmountInvoiceDialogProps, dialogRef) => {
  const { translate } = useInternationalization()

  const [updateCustomerFinalizeZeroAmountInvoice] =
    useUpdateCustomerFinalizeZeroAmountInvoiceMutation({
      onCompleted(res) {
        if (res?.updateCustomer) {
          addToast({
            severity: 'success',
            translateKey: translate('text_1725549671288cyc585wdz35'),
          })
        }
      },
    })

  const [updateBillingEntityFinalizeZeroAmountInvoice] =
    useUpdateBillingEntityFinalizeZeroAmountInvoiceMutation({
      onCompleted(res) {
        if (res?.updateBillingEntity) {
          addToast({
            severity: 'success',
            translateKey: translate('text_17255496712882bspi9zp0ii'),
          })
        }
      },
      refetchQueries: ['getBillingEntitySettings'],
    })

  const isCustomer = entity?.__typename === 'Customer'

  const getInitialValue = () => {
    if (isCustomer) {
      return finalizeZeroAmountInvoice === FinalizeZeroAmountInvoiceEnum.Inherit
        ? ''
        : finalizeZeroAmountInvoice
    }
    return finalizeZeroAmountInvoice?.toString()
  }

  const initialValue = getInitialValue()

  const formikProps = useFormik({
    initialValues: {
      finalizeZeroAmountInvoice: initialValue,
    },
    validationSchema: object().shape({
      finalizeZeroAmountInvoice: string().required(),
    }),
    validateOnMount: true,
    enableReinitialize: true,
    onSubmit: async (values) => {
      if (!values.finalizeZeroAmountInvoice) {
        return
      }

      if (isCustomer) {
        return await updateCustomerFinalizeZeroAmountInvoice({
          variables: {
            input: {
              id: entity?.id || '',
              externalId: entity.externalId,
              name: entity?.name || '',
              finalizeZeroAmountInvoice:
                values?.finalizeZeroAmountInvoice as FinalizeZeroAmountInvoiceEnum,
            },
          },
        })
      }

      return await updateBillingEntityFinalizeZeroAmountInvoice({
        variables: {
          input: {
            id: (entity as EditBillingEntityFinalizeZeroAmountInvoiceForDialogFragment)?.id,
            finalizeZeroAmountInvoice: values.finalizeZeroAmountInvoice === 'true',
          },
        },
      })
    },
  })

  const comboBoxData = isCustomer
    ? [
        { value: 'finalize', label: translate('text_1725549671287ancbf00edxx') },
        { value: 'skip', label: translate('text_1725549671288zkq9sr0y46l') },
      ]
    : [
        { value: 'true', label: translate('text_1725549671287ancbf00edxx') },
        { value: 'false', label: translate('text_1725549671288zkq9sr0y46l') },
      ]

  return (
    <Dialog
      ref={dialogRef}
      title={translate('text_17255383402002zmj6x02fx8')}
      description={translate('text_1725538340200495slgen6ji')}
      onClose={() => {
        formikProps.resetForm()
      }}
      actions={({ closeDialog }) => (
        <>
          <Button variant="quaternary" onClick={closeDialog}>
            {translate('text_62bb10ad2a10bd182d002031')}
          </Button>
          <Button
            variant="primary"
            disabled={!formikProps.isValid || !formikProps.dirty}
            onClick={async () => {
              await formikProps.submitForm()
              closeDialog()
              formikProps.resetForm()
            }}
          >
            {translate('text_17432414198706rdwf76ek3u')}
          </Button>
        </>
      )}
    >
      <div className="mb-8 flex flex-col gap-3">
        <ComboBoxField
          disableClearable
          name="finalizeZeroAmountInvoice"
          placeholder={translate('text_1725550661207stz6kovtzkp')}
          label={translate('text_1725549671288gcrvgdn7rml')}
          data={comboBoxData}
          PopperProps={{ displayInDialog: true }}
          formikProps={formikProps}
        />
      </div>
    </Dialog>
  )
})

EditFinalizeZeroAmountInvoiceDialog.displayName = 'forwardRef'
