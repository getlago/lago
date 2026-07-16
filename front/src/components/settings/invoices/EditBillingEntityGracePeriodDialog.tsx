import { gql } from '@apollo/client'
import InputAdornment from '@mui/material/InputAdornment'
import { revalidateLogic, useStore } from '@tanstack/react-form'
import { forwardRef, useImperativeHandle, useRef } from 'react'
import { z } from 'zod'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { addToast } from '~/core/apolloClient'
import { useUpdateBillingEntityGracePeriodMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

gql`
  mutation updateBillingEntityGracePeriod($input: UpdateBillingEntityInput!) {
    updateBillingEntity(input: $input) {
      id
      billingConfiguration {
        id
        invoiceGracePeriod
      }
    }
  }
`

const editBillingEntityGracePeriodValidationSchema = z.object({
  // Empty input is treated as 0 (see onSubmit coercion below), so it is a valid value.
  invoiceGracePeriod: z.union([
    z.number().max(365, { message: 'text_63bed78ae69de9cad5c348e4' }),
    z.literal(''),
  ]),
})

export type EditBillingEntityGracePeriodDialogRef = DialogRef

interface EditBillingEntityGracePeriodDialogProps {
  id: string
  invoiceGracePeriod: number
}

const FORM_ID = 'edit-billing-entity-grace-period-form'

export const EditBillingEntityGracePeriodDialog = forwardRef<
  DialogRef,
  EditBillingEntityGracePeriodDialogProps
>(({ id, invoiceGracePeriod }: EditBillingEntityGracePeriodDialogProps, ref) => {
  const { translate } = useInternationalization()
  const dialogRef = useRef<DialogRef>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  useImperativeHandle(ref, () => ({
    openDialog: () => dialogRef.current?.openDialog(),
    closeDialog: () => dialogRef.current?.closeDialog(),
  }))

  const [updateBillingEntityGracePeriod] = useUpdateBillingEntityGracePeriodMutation({
    onCompleted(res) {
      if (res?.updateBillingEntity) {
        addToast({
          severity: 'success',
          translateKey: 'text_638dc196fb209d551f3d81ba',
        })
      }
    },
    refetchQueries: ['getBillingEntitySettings'],
  })

  const form = useAppForm({
    defaultValues: {
      invoiceGracePeriod: (invoiceGracePeriod ?? '') as number | '',
    },
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: editBillingEntityGracePeriodValidationSchema,
    },
    onSubmit: async ({ value }) => {
      await updateBillingEntityGracePeriod({
        variables: {
          input: {
            id,
            billingConfiguration: {
              invoiceGracePeriod: Number(value.invoiceGracePeriod) || 0,
            },
          },
        },
      })
      dialogRef.current?.closeDialog()
    },
  })

  const isDirty = useStore(form.store, (state) => state.isDirty)
  const canSubmit = useStore(form.store, (state) => state.canSubmit)

  const handleFormSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    form.handleSubmit()
  }

  const actions = ({ closeDialog }: { closeDialog: () => void }) => (
    <>
      <Button variant="quaternary" onClick={closeDialog}>
        {translate('text_62bb10ad2a10bd182d002031')}
      </Button>
      <Button variant="primary" type="submit" disabled={!canSubmit || !isDirty}>
        {translate('text_17432414198706rdwf76ek3u')}
      </Button>
    </>
  )

  return (
    <Dialog
      ref={dialogRef}
      title={translate('text_638dc196fb209d551f3d8139')}
      description={translate('text_638dc196fb209d551f3d813b')}
      onOpen={() => form.reset()}
      onClose={() => form.reset()}
      onEntered={() => inputRef.current?.focus()}
      formId={FORM_ID}
      formSubmit={handleFormSubmit}
      actions={actions}
    >
      <div className="mb-8">
        <form.AppField name="invoiceGracePeriod">
          {(field) => (
            <field.TextInputField
              inputRef={inputRef}
              beforeChangeFormatter={['positiveNumber', 'int']}
              label={translate('text_638dc196fb209d551f3d819d')}
              placeholder={translate('text_638dc196fb209d551f3d8147')}
              InputProps={{
                endAdornment: (
                  <InputAdornment position="end">
                    {translate('text_638dc196fb209d551f3d814d')}
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

EditBillingEntityGracePeriodDialog.displayName = 'EditBillingEntityGracePeriodDialog'
