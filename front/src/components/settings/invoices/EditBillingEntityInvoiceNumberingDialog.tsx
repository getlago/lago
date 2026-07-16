import { gql } from '@apollo/client'
import { useFormik } from 'formik'
import { forwardRef } from 'react'
import { object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { Typography } from '~/components/designSystem/Typography'
import { RadioGroupField, TextInput, TextInputField } from '~/components/form'
import { addToast } from '~/core/apolloClient'
import { getBillingEntityNumberPreview } from '~/core/utils/billingEntityNumberPreview'
import {
  BillingEntityDocumentNumberingEnum,
  useUpdateBillingEntityInvoiceNumberingMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

const DynamicPrefixTranslationLookup = {
  [BillingEntityDocumentNumberingEnum.PerCustomer]: 'text_6566f920a1d6c35693d6cce0',
  [BillingEntityDocumentNumberingEnum.PerBillingEntity]: 'YYYYMM',
}

gql`
  fragment EditBillingEntityInvoiceNumberingDialog on BillingEntity {
    id
    documentNumbering
    documentNumberPrefix
  }

  mutation updateBillingEntityInvoiceNumbering($input: UpdateBillingEntityInput!) {
    updateBillingEntity(input: $input) {
      id
      ...EditBillingEntityInvoiceNumberingDialog
    }
  }
`

export type EditBillingEntityInvoiceNumberingDialogRef = DialogRef

interface EditBillingEntityInvoiceNumberingDialogProps {
  id: string
  documentNumbering?: BillingEntityDocumentNumberingEnum
  documentNumberPrefix?: string
}

export const EditBillingEntityInvoiceNumberingDialog = forwardRef<
  DialogRef,
  EditBillingEntityInvoiceNumberingDialogProps
>(
  (
    { id, documentNumbering, documentNumberPrefix }: EditBillingEntityInvoiceNumberingDialogProps,
    ref,
  ) => {
    const { translate } = useInternationalization()
    const [updateBillingEntityInvoiceNumbering] = useUpdateBillingEntityInvoiceNumberingMutation({
      onCompleted(res) {
        if (res?.updateBillingEntity) {
          addToast({
            severity: 'success',
            translateKey: 'text_6566f920a1d6c35693d6ce0f',
          })
        }
      },
      refetchQueries: ['getBillingEntitySettings'],
    })

    // Type is manually written here as errors type are not correctly read from UpdateBillingEntityInput
    const formikProps = useFormik<EditBillingEntityInvoiceNumberingDialogProps>({
      initialValues: {
        id,
        documentNumbering,
        documentNumberPrefix,
      },
      validationSchema: object().shape({
        documentNumbering: string().required(''),
        documentNumberPrefix: string().required('').max(10, 'text_6566f920a1d6c35693d6cd77'),
      }),
      enableReinitialize: true,
      validateOnMount: true,
      onSubmit: async (values) => {
        await updateBillingEntityInvoiceNumbering({
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
        title={translate('text_6566f920a1d6c35693d6cc8c')}
        description={translate('text_6566f920a1d6c35693d6cc94')}
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
        <div className="mb-8 flex flex-col gap-8">
          <div className="flex items-center gap-3 rounded-xl border border-grey-300 p-3">
            <Chip label={translate('text_6566f920a1d6c35693d6cc9e')} />
            <Typography variant="body" color="grey700">
              {getBillingEntityNumberPreview(
                formikProps.values.documentNumbering as BillingEntityDocumentNumberingEnum,
                formikProps.values.documentNumberPrefix || '',
              )}
            </Typography>
          </div>

          <RadioGroupField
            formikProps={formikProps}
            name="documentNumbering"
            label={translate('text_6566f920a1d6c35693d6ccae')}
            options={[
              {
                label: translate('text_6566f920a1d6c35693d6ccb8'),
                value: BillingEntityDocumentNumberingEnum.PerCustomer,
              },
              {
                label: translate('text_6566f920a1d6c35693d6ccc0'),
                value: BillingEntityDocumentNumberingEnum.PerBillingEntity,
              },
            ]}
          />

          <div className="grid grid-cols-[1fr_8px_1fr_8px_80px] gap-3">
            <TextInputField
              name="documentNumberPrefix"
              formikProps={formikProps}
              label={translate('text_6566f920a1d6c35693d6ccc8')}
              error={
                formikProps.errors.documentNumberPrefix
                  ? translate(formikProps.errors.documentNumberPrefix)
                  : undefined
              }
            />
            <Typography className="mt-[38px] h-fit" variant="body">
              -
            </Typography>
            <TextInput
              disabled
              label={translate('text_6566f920a1d6c35693d6ccd8')}
              value={translate(
                DynamicPrefixTranslationLookup[
                  formikProps.values.documentNumbering as BillingEntityDocumentNumberingEnum
                ],
              )}
            />
            <Typography className="mt-[38px] h-fit" variant="body">
              -
            </Typography>
            <TextInput disabled label={translate('text_6566f920a1d6c35693d6cce8')} value={'001'} />
          </div>
        </div>
      </Dialog>
    )
  },
)

EditBillingEntityInvoiceNumberingDialog.displayName = 'forwardRef'
