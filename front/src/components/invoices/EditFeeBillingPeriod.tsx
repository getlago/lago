import { revalidateLogic } from '@tanstack/react-form'
import { DateTime } from 'luxon'
import { useRef } from 'react'
import { z } from 'zod'

import { useFormDialog } from '~/components/dialogs/FormDialog'
import { DialogResult } from '~/components/dialogs/types'
import { DatePicker } from '~/components/form'
import { dateErrorCodes } from '~/core/constants/form'
import { getTimezoneConfig } from '~/core/timezone'
import { TimezoneEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

export const EDIT_FEE_BILLING_PERIOD_FORM_ID = 'edit-fee-billing-period-form'

type OpenEditFeeBillingPeriodDialogParams = {
  fromDatetime: string
  toDatetime: string
  callback: (fromDatetime: string, toDatetime: string) => void
}

const editFeeBillingPeriodValidationSchema = z
  .object({
    fromDatetime: z.string().min(1, { message: '' }),
    toDatetime: z.string(),
  })
  .refine((data) => !data.toDatetime || DateTime.fromISO(data.toDatetime).isValid, {
    message: dateErrorCodes.wrongFormat,
    path: ['toDatetime'],
  })
  .refine(
    (data) => {
      if (!data.toDatetime || !data.fromDatetime) {
        return true
      }

      return DateTime.fromISO(data.toDatetime) > DateTime.fromISO(data.fromDatetime)
    },
    {
      message: dateErrorCodes.shouldBeFutureAndBiggerThanFromDatetime,
      path: ['toDatetime'],
    },
  )

export const useEditFeeBillingPeriodDialog = () => {
  const formDialog = useFormDialog()
  const { translate } = useInternationalization()
  const callbackRef = useRef<((fromDatetime: string, toDatetime: string) => void) | null>(null)

  const form = useAppForm({
    defaultValues: {
      fromDatetime: '',
      toDatetime: '',
    },
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: editFeeBillingPeriodValidationSchema,
    },
    onSubmit: async ({ value }) => {
      callbackRef.current?.(value.fromDatetime || '', value.toDatetime || '')
    },
  })

  const handleSubmit = async (): Promise<DialogResult> => {
    await form.handleSubmit()

    // On validation error onSubmit never runs and isSubmitSuccessful stays false:
    // throw to keep the dialog open (closeOnError: false swallows the error, inline
    // field errors stay visible). Returning a result would let FormDialog close it.
    if (!form.state.isSubmitSuccessful) {
      throw new Error('Submit failed')
    }

    return { reason: 'success' }
  }

  const openEditFeeBillingPeriodDialog = ({
    fromDatetime,
    toDatetime,
    callback,
  }: OpenEditFeeBillingPeriodDialogParams) => {
    callbackRef.current = callback
    form.reset(
      { fromDatetime: fromDatetime ?? '', toDatetime: toDatetime ?? '' },
      { keepDefaultValues: true },
    )

    formDialog
      .open({
        title: translate('text_1754596547718sagqs9n5z2w'),
        description: translate('text_1754596547719py3gxrwmgdo'),
        cancelOrCloseText: 'cancel',
        children: (
          <div className="flex items-start gap-6 p-8 [&>*]:flex-1">
            <form.AppField name="fromDatetime">
              {(field) => (
                <DatePicker
                  name="fromDatetime"
                  label={translate('text_1754596347194ycmhkuol77d')}
                  defaultZone={getTimezoneConfig(TimezoneEnum.TzUtc).name}
                  value={field.state.value}
                  onChange={(value) => {
                    // value should be start of day
                    field.handleChange(
                      value ? DateTime.fromISO(value).startOf('day').toISO() || '' : '',
                    )
                  }}
                />
              )}
            </form.AppField>
            <form.AppField name="toDatetime">
              {(field) => (
                <DatePicker
                  name="toDatetime"
                  label={translate('text_1754596347194hgyj8fzogqm')}
                  defaultZone={getTimezoneConfig(TimezoneEnum.TzUtc).name}
                  value={field.state.value}
                  error={
                    field.state.meta.errors?.[0]?.message ===
                    dateErrorCodes.shouldBeFutureAndBiggerThanFromDatetime
                      ? translate('text_175459724137023yixxoovqg')
                      : undefined
                  }
                  onChange={(value) => {
                    field.handleChange(
                      value ? DateTime.fromISO(value).endOf('day').toISO() || '' : '',
                    )
                  }}
                />
              )}
            </form.AppField>
          </div>
        ),
        closeOnError: false,
        mainAction: (
          <form.AppForm>
            <form.SubmitButton>{translate('text_17295436903260tlyb1gp1i7')}</form.SubmitButton>
          </form.AppForm>
        ),
        form: {
          id: EDIT_FEE_BILLING_PERIOD_FORM_ID,
          submit: handleSubmit,
        },
      })
      .then((response) => {
        if (response.reason === 'close') {
          form.reset()
          callbackRef.current = null
        }
      })
  }

  return { openEditFeeBillingPeriodDialog }
}
