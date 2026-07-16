import { revalidateLogic } from '@tanstack/react-form'
import { useCallback, useState } from 'react'
import { z } from 'zod'

import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { useDrawer } from '~/components/drawers/useDrawer'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm, withForm } from '~/hooks/forms/useAppform'

export const SUBSCRIPTION_SETTINGS_DRAWER_SAVE_TEST_ID = 'subscription-settings-drawer-save'

export interface SubscriptionSettingsFormValues {
  externalId: string
  subscriptionName: string
  billingTime: 'anniversary' | 'calendar'
  startDate: string
  endDate: string
}

const subscriptionSettingsSchema = z
  .object({
    externalId: z.string(),
    subscriptionName: z.string(),
    billingTime: z.enum(['anniversary', 'calendar']),
    startDate: z.string().min(1, 'text_624ea7c29103fd010732ab7d'),
    endDate: z.string(),
  })
  .superRefine((data, ctx) => {
    if (data.endDate && data.startDate && data.endDate < data.startDate) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'End date must be after start date',
        path: ['endDate'],
      })
    }
  })

const DEFAULT_VALUES: SubscriptionSettingsFormValues = {
  externalId: '',
  subscriptionName: '',
  billingTime: 'anniversary',
  startDate: '',
  endDate: '',
}

const SubscriptionSettingsDrawerContent = withForm({
  defaultValues: DEFAULT_VALUES,
  props: {
    initialValues: DEFAULT_VALUES,
    isAmendment: false,
  },
  render: function Render({ form, initialValues, isAmendment }) {
    const { translate } = useInternationalization()
    const [showExternalId, setShowExternalId] = useState(!!initialValues.externalId)
    const [showSubscriptionName, setShowSubscriptionName] = useState(
      !!initialValues.subscriptionName,
    )

    return (
      <div className="flex flex-col gap-6">
        <CenteredPage.PageTitle
          title={translate('text_17791987800304a3fihrighy')}
          description={translate('text_66630368f4333b00795b0e1c')}
        />
        {showExternalId && (
          <div className="flex flex-row gap-3 [&>*:first-child]:flex-1">
            <form.AppField name="externalId">
              {(field) => (
                <field.TextInputField
                  label={translate('text_642a94e522316cd9e1875224')}
                  placeholder={translate('text_642ac1d1407baafb9e4390ee')}
                  helperText={translate('text_642ac28c65c2180085afe31a')}
                />
              )}
            </form.AppField>
            <Tooltip
              className="mt-7 h-fit"
              placement="top-end"
              title={translate('text_63aa085d28b8510cd46443ff')}
            >
              <Button
                icon="trash"
                variant="quaternary"
                onClick={() => {
                  form.setFieldValue('externalId', '')
                  setShowExternalId(false)
                }}
              />
            </Tooltip>
          </div>
        )}
        {showSubscriptionName && (
          <div className="flex flex-row gap-3 [&>*:first-child]:flex-1">
            <form.AppField name="subscriptionName">
              {(field) => (
                <field.TextInputField
                  label={translate('text_62d7f6178ec94cd09370e2b9')}
                  placeholder={translate('text_62d7f6178ec94cd09370e2cb')}
                  helperText={translate('text_62d7f6178ec94cd09370e2d9')}
                />
              )}
            </form.AppField>
            <Tooltip
              className="mt-7 h-fit"
              placement="top-end"
              title={translate('text_63aa085d28b8510cd46443ff')}
            >
              <Button
                icon="trash"
                variant="quaternary"
                onClick={() => {
                  form.setFieldValue('subscriptionName', '')
                  setShowSubscriptionName(false)
                }}
              />
            </Tooltip>
          </div>
        )}

        {(!showExternalId || !showSubscriptionName) && (
          <div className="flex items-center gap-4">
            {!showExternalId && (
              <Button
                startIcon="plus"
                variant="inline"
                onClick={() => setShowExternalId(true)}
                data-test="show-external-id"
              >
                {translate('text_65118a52df984447c1869472')}
              </Button>
            )}
            {!showSubscriptionName && (
              <Button
                startIcon="plus"
                variant="inline"
                onClick={() => setShowSubscriptionName(true)}
                data-test="show-name"
              >
                {translate('text_65118a52df984447c186947c')}
              </Button>
            )}
          </div>
        )}
        <div>
          <Typography variant="captionHl" color="grey700" className="mb-1">
            {translate('text_62ea7cd44cd4b14bb9ac1db7')}
          </Typography>
          <Typography variant="caption" color="grey600" className="mb-3">
            {translate('text_62ea7cd44cd4b14bb9ac1db9')}
          </Typography>
          <form.AppField name="billingTime">
            {(field) => (
              <field.RadioGroupField
                options={[
                  {
                    value: 'anniversary',
                    label: translate('text_1776883338722o7e5us2iq7h'),
                    sublabel: translate('text_62ea7cd44cd4b14bb9ac1dbd'),
                  },
                  {
                    value: 'calendar',
                    label: translate('text_177688333872224m25xpq3m2'),
                    sublabel: translate('text_62ea7cd44cd4b14bb9ac1dbf'),
                  },
                ]}
              />
            )}
          </form.AppField>
        </div>
        <div className="flex gap-3">
          <form.AppField name="startDate">
            {(field) => (
              <field.DatePickerField
                disabled={isAmendment}
                label={translate('text_65201c5a175a4b0238abf29e')}
                className="flex-1"
              />
            )}
          </form.AppField>
          <form.AppField name="endDate">
            {(field) => (
              <field.DatePickerField
                label={`${translate('text_65201c5a175a4b0238abf2a0')} (${translate('text_63aa085d28b8510cd46443ff')})`}
                className="flex-1"
              />
            )}
          </form.AppField>
        </div>
      </div>
    )
  },
})

export const useSubscriptionSettingsDrawer = (
  onSave: (values: SubscriptionSettingsFormValues) => void,
  isAmendment = false,
) => {
  const { translate } = useInternationalization()
  const drawer = useDrawer()

  const form = useAppForm({
    defaultValues: DEFAULT_VALUES,
    validationLogic: revalidateLogic(),
    validators: { onDynamic: subscriptionSettingsSchema },
    onSubmit: async ({ value }) => {
      onSave(value)
      drawer.close()
    },
  })

  const handleFormSubmit = (event?: React.FormEvent) => {
    event?.preventDefault()
    form.handleSubmit()
  }

  const openDrawer = useCallback(
    (values: SubscriptionSettingsFormValues) => {
      form.reset(values, { keepDefaultValues: true })

      drawer.open({
        title: translate('text_17791987800304a3fihrighy'),
        children: (
          <form onSubmit={handleFormSubmit}>
            <button type="submit" hidden tabIndex={-1} />
            <SubscriptionSettingsDrawerContent
              form={form}
              initialValues={values}
              isAmendment={isAmendment}
            />
          </form>
        ),
        actions: (
          <div className="flex items-center justify-end gap-3">
            <Button variant="quaternary" onClick={() => drawer.close()}>
              {translate('text_6411e6b530cb47007488b027')}
            </Button>
            <form.Subscribe selector={({ canSubmit }) => canSubmit}>
              {(canSubmit) => (
                <Button
                  data-test={SUBSCRIPTION_SETTINGS_DRAWER_SAVE_TEST_ID}
                  onClick={handleFormSubmit}
                  disabled={!canSubmit}
                >
                  {translate('text_17295436903260tlyb1gp1i7')}
                </Button>
              )}
            </form.Subscribe>
          </div>
        ),
      })
    },
    // isAmendment and handleFormSubmit are stable (param + closure over form) — safe to omit
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [drawer, form, translate],
  )

  return { openDrawer }
}
