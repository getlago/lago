import { gql } from '@apollo/client'
import { revalidateLogic, useStore } from '@tanstack/react-form'
import { forwardRef, useImperativeHandle, useRef } from 'react'
import { z } from 'zod'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { Typography } from '~/components/designSystem/Typography'
import { addToast } from '~/core/apolloClient'
import { documentLocalesDataForComboBox } from '~/core/translations/documentLocales'
import { LagoApiError, useUpdateDocumentLocaleBillingEntityMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

gql`
  mutation updateDocumentLocaleBillingEntity($input: UpdateBillingEntityInput!) {
    updateBillingEntity(input: $input) {
      id
      billingConfiguration {
        id
        documentLocale
      }
    }
  }
`

const editBillingEntityDocumentLocaleValidationSchema = z.object({
  // The combobox emits `undefined` when cleared, so cover both the missing
  // (invalid_type) and empty-string cases with the same "required" message.
  documentLocale: z
    .string({ message: 'text_624ea7c29103fd010732ab7d' })
    .min(1, { message: 'text_624ea7c29103fd010732ab7d' }),
})

export type EditBillingEntityDocumentLocaleDialogRef = DialogRef

interface EditBillingEntityDocumentLocaleDialogProps {
  id: string
  documentLocale: string
}

const FORM_ID = 'edit-billing-entity-document-locale-form'

export const EditBillingEntityDocumentLocaleDialog = forwardRef<
  DialogRef,
  EditBillingEntityDocumentLocaleDialogProps
>(({ id, documentLocale }: EditBillingEntityDocumentLocaleDialogProps, ref) => {
  const { translate } = useInternationalization()
  const dialogRef = useRef<DialogRef>(null)

  useImperativeHandle(ref, () => ({
    openDialog: () => dialogRef.current?.openDialog(),
    closeDialog: () => dialogRef.current?.closeDialog(),
  }))

  const [updateDocumentLocale] = useUpdateDocumentLocaleBillingEntityMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted(res) {
      if (res?.updateBillingEntity) {
        addToast({
          severity: 'success',
          translateKey: 'text_63e51ef4985f0ebd75c21349',
        })
      }
    },
    refetchQueries: ['getBillingEntitySettings'],
  })

  const form = useAppForm({
    defaultValues: {
      documentLocale,
    },
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: editBillingEntityDocumentLocaleValidationSchema,
    },
    onSubmit: async ({ value }) => {
      await updateDocumentLocale({
        variables: {
          input: {
            id,
            billingConfiguration: {
              documentLocale: value.documentLocale,
            },
          },
        },
      })
      dialogRef.current?.closeDialog()
    },
  })

  const isDirty = useStore(form.store, (state) => state.isDirty)

  const handleFormSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    form.handleSubmit()
  }

  const actions = ({ closeDialog }: { closeDialog: () => void }) => (
    <>
      <Button variant="quaternary" onClick={closeDialog}>
        {translate('text_63e51ef4985f0ebd75c21313')}
      </Button>
      <form.AppForm>
        <form.SubmitButton variant="primary" disabled={!isDirty}>
          {translate('text_17432414198706rdwf76ek3u')}
        </form.SubmitButton>
      </form.AppForm>
    </>
  )

  return (
    <Dialog
      ref={dialogRef}
      title={translate('text_63e51ef4985f0ebd75c2130e')}
      description={translate('text_63e51ef4985f0ebd75c2130f')}
      onOpen={() => form.reset()}
      onClose={() => form.reset()}
      formId={FORM_ID}
      formSubmit={handleFormSubmit}
      actions={actions}
    >
      <div className="mb-8">
        <form.AppField name="documentLocale">
          {(field) => (
            <field.ComboBoxField
              disableClearable
              label={translate('text_63e51ef4985f0ebd75c21310')}
              helperText={
                <Typography variant="caption" html={translate('text_63e51ef4985f0ebd75c21312')} />
              }
              data={documentLocalesDataForComboBox}
              PopperProps={{ displayInDialog: true }}
            />
          )}
        </form.AppField>
      </div>
    </Dialog>
  )
})

EditBillingEntityDocumentLocaleDialog.displayName = 'EditBillingEntityDocumentLocaleDialog'
