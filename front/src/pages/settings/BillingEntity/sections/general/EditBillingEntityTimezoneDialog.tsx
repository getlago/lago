import { gql } from '@apollo/client'
import { revalidateLogic } from '@tanstack/react-form'
import { Settings } from 'luxon'
import { useRef } from 'react'
import { z } from 'zod'

import { useFormDialog } from '~/components/dialogs/FormDialog'
import { DialogResult } from '~/components/dialogs/types'
import { addToast } from '~/core/apolloClient'
import { getTimezoneConfig } from '~/core/timezone'
import { TimezoneEnum, useUpdateBillingEntityTimezoneMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

gql`
  mutation updateBillingEntityTimezone($input: UpdateBillingEntityInput!) {
    updateBillingEntity(input: $input) {
      id
      timezone
    }
  }
`

const editBillingEntityTimezoneValidationSchema = z.object({
  timezone: z.enum(TimezoneEnum).optional(),
})

type EditBillingEntityTimezoneFormValues = z.infer<typeof editBillingEntityTimezoneValidationSchema>

export const EDIT_BILLING_ENTITY_TIMEZONE_FORM_ID = 'edit-billing-entity-timezone-form'
const EDIT_BILLING_ENTITY_TIMEZONE_COMBOBOX_TEST_ID = 'edit-billing-entity-timezone-combobox'

export const EDIT_BILLING_ENTITY_TIMEZONE_SUBMIT_BUTTON_TEST_ID =
  'edit-billing-entity-timezone-submit-button'

const initialValues: EditBillingEntityTimezoneFormValues = {
  timezone: undefined,
}

type EditBillingEntityTimezoneData = {
  id?: string
  timezone?: TimezoneEnum | null
}

export const useEditBillingEntityTimezoneDialog = () => {
  const formDialog = useFormDialog()
  const { translate } = useInternationalization()
  const dataRef = useRef<EditBillingEntityTimezoneData | null>(null)
  const successRef = useRef(false)

  const [update] = useUpdateBillingEntityTimezoneMutation({
    onCompleted(res) {
      if (res?.updateBillingEntity) {
        addToast({
          severity: 'success',
          translateKey: 'text_63891ad3dd238c657ea00954',
        })
        Settings.defaultZone = getTimezoneConfig(res?.updateBillingEntity?.timezone).name
      }
    },
  })

  const form = useAppForm({
    defaultValues: initialValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: editBillingEntityTimezoneValidationSchema,
    },
    onSubmit: async ({ value }) => {
      const selectedTimezone = value.timezone || TimezoneEnum.TzUtc

      const result = await update({
        variables: {
          input: {
            id: dataRef.current?.id as string,
            timezone: selectedTimezone,
          },
        },
      })

      if (result.data?.updateBillingEntity) {
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

  const openEditBillingEntityTimezoneDialog = (data: EditBillingEntityTimezoneData) => {
    dataRef.current = data
    form.reset()
    form.setFieldValue('timezone', data.timezone ?? undefined)

    formDialog
      .open({
        title: translate('text_63890710eb171a76814a0c0d'),
        description: translate('text_63890710eb171a76814a0c0f'),
        cancelOrCloseText: 'cancel',
        closeOnError: false,
        children: (
          <div className="p-8">
            <form.AppField name="timezone">
              {(field) => (
                <field.ComboBoxField
                  dataTest={EDIT_BILLING_ENTITY_TIMEZONE_COMBOBOX_TEST_ID}
                  label={translate('text_63890710eb171a76814a0c11')}
                  PopperProps={{ displayInDialog: true }}
                  placeholder={translate('text_6390a4ffef9227ba45daca92')}
                  data={Object.values(TimezoneEnum).map((timezoneValue) => ({
                    value: timezoneValue,
                    label: translate('text_638f743fa9a2a9545ee6409a', {
                      zone: translate(timezoneValue),
                      offset: getTimezoneConfig(timezoneValue).offset,
                    }),
                  }))}
                />
              )}
            </form.AppField>
          </div>
        ),
        mainAction: (
          <form.AppForm>
            <form.SubmitButton dataTest={EDIT_BILLING_ENTITY_TIMEZONE_SUBMIT_BUTTON_TEST_ID}>
              {translate('text_63890710eb171a76814a0c17')}
            </form.SubmitButton>
          </form.AppForm>
        ),
        form: {
          id: EDIT_BILLING_ENTITY_TIMEZONE_FORM_ID,
          submit: handleSubmit,
        },
      })
      .then((response) => {
        if (response.reason === 'close') {
          form.reset()
          dataRef.current = null
        }
      })
  }

  return { openEditBillingEntityTimezoneDialog }
}
