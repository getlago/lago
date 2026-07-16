import { revalidateLogic } from '@tanstack/react-form'
import { ReactNode } from 'react'

import { useFormDialog } from '~/components/dialogs/FormDialog'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

const CASCADE_FORM_ID = 'cascade-updates-form'

type OpenCascadeDialogInput = {
  title: ReactNode
  description?: ReactNode
  mainActionLabel: string
  hasOverriddenPlans: boolean
  onConfirm: (cascadeUpdates: boolean) => Promise<void> | void
  danger?: boolean
}

type SubmitMeta = {
  onConfirm: OpenCascadeDialogInput['onConfirm']
}

export const useCascadeFormDialog = () => {
  const { translate } = useInternationalization()
  const formDialog = useFormDialog()

  const form = useAppForm({
    defaultValues: { cascadeUpdates: true },
    validationLogic: revalidateLogic(),
    onSubmitMeta: {} as SubmitMeta,
    onSubmit: async ({ value, meta }) => {
      await meta.onConfirm(value.cascadeUpdates)
    },
  })

  const openCascadeDialog = async (input: OpenCascadeDialogInput): Promise<boolean> => {
    if (!input.hasOverriddenPlans) {
      await input.onConfirm(false)
      return true
    }

    form.reset()

    let confirmed = false

    await formDialog.open({
      title: input.title,
      description: input.description,
      form: {
        id: CASCADE_FORM_ID,
        submit: async () => {
          await form.handleSubmit({
            onConfirm: async (cascadeUpdates) => {
              await input.onConfirm(cascadeUpdates)
              confirmed = true
            },
          })
        },
      },
      mainAction: (
        <form.AppForm>
          <form.SubmitButton danger={input.danger}>{input.mainActionLabel}</form.SubmitButton>
        </form.AppForm>
      ),
      children: (
        <form.AppForm>
          <div className="p-8">
            <form.AppField name="cascadeUpdates">
              {(field) => (
                <field.SwitchField
                  label={translate('text_1779289915866s3gisblcite')}
                  subLabel={translate('text_1779289915866itrqeyj7658')}
                />
              )}
            </form.AppField>
          </div>
        </form.AppForm>
      ),
    })

    return confirmed
  }

  return { openCascadeDialog }
}
