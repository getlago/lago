import { gql } from '@apollo/client'
import { useFormik } from 'formik'
import { forwardRef } from 'react'
import { object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { TextInputField } from '~/components/form'
import { addToast } from '~/core/apolloClient'
import { useUpdateBillingEntityInvoiceTemplateMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

const MAX_CHAR_LIMIT = 600

gql`
  fragment EditBillingEntityInvoiceTemplateDialog on BillingEntity {
    billingConfiguration {
      id
      invoiceFooter
    }
  }

  mutation updateBillingEntityInvoiceTemplate($input: UpdateBillingEntityInput!) {
    updateBillingEntity(input: $input) {
      id
      ...EditBillingEntityInvoiceTemplateDialog
    }
  }
`

export type EditBillingEntityInvoiceTemplateDialogRef = DialogRef

interface EditBillingEntityInvoiceTemplateDialogProps {
  id: string
  invoiceFooter: string
}

export const EditBillingEntityInvoiceTemplateDialog = forwardRef<
  DialogRef,
  EditBillingEntityInvoiceTemplateDialogProps
>(({ id, invoiceFooter }: EditBillingEntityInvoiceTemplateDialogProps, ref) => {
  const { translate } = useInternationalization()
  const [updateBillingEntityInvoiceTemplate] = useUpdateBillingEntityInvoiceTemplateMutation({
    onCompleted(res) {
      if (res?.updateBillingEntity) {
        addToast({
          severity: 'success',
          translateKey: 'text_62bb10ad2a10bd182d002077',
        })
      }
    },
    refetchQueries: ['getBillingEntitySettings'],
  })

  // Type is manually written here as errors type are not correclty read from UpdateBillingEntityInput
  const formikProps = useFormik<{ id: string; billingConfiguration: { invoiceFooter: string } }>({
    initialValues: {
      id,
      billingConfiguration: { invoiceFooter },
    },
    validationSchema: object().shape({
      billingConfiguration: object().shape({
        invoiceFooter: string().max(600, 'text_62bb10ad2a10bd182d00203b'),
      }),
    }),
    enableReinitialize: true,
    validateOnMount: true,
    onSubmit: async (values) => {
      await updateBillingEntityInvoiceTemplate({
        variables: {
          input: {
            ...values,
          },
        },
      })
    },
  })

  return (
    <Dialog
      ref={ref}
      title={translate('text_62bb10ad2a10bd182d00201d')}
      onClose={() => formikProps.resetForm()}
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
            }}
          >
            {translate('text_17432414198706rdwf76ek3u')}
          </Button>
        </>
      )}
    >
      <div className="mb-8">
        <TextInputField
          className="whitespace-pre-line"
          name="billingConfiguration.invoiceFooter"
          rows="4"
          multiline
          label={translate('text_62bb10ad2a10bd182d002023')}
          placeholder={translate('text_62bb10ad2a10bd182d00202b')}
          // eslint-disable-next-line jsx-a11y/no-autofocus
          autoFocus
          formikProps={formikProps}
          error={formikProps.errors?.billingConfiguration?.invoiceFooter}
          helperText={
            <div className="flex justify-between">
              <div className="flex-1">
                {!!formikProps.errors?.billingConfiguration?.invoiceFooter
                  ? translate('text_62bb10ad2a10bd182d00203b')
                  : translate('text_62bc52dd8536260acc9eb762')}
              </div>
              <div className="shrink-0">
                {formikProps.values.billingConfiguration?.invoiceFooter?.length}/{MAX_CHAR_LIMIT}
              </div>
            </div>
          }
        />
      </div>
    </Dialog>
  )
})

EditBillingEntityInvoiceTemplateDialog.displayName = 'forwardRef'
