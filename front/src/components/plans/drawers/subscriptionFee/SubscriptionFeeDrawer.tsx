import InputAdornment from '@mui/material/InputAdornment'
import { revalidateLogic } from '@tanstack/react-form'
import { forwardRef, useImperativeHandle } from 'react'
import { z } from 'zod'

import { useFormDrawer } from '~/components/drawers/useDrawer'
import { focusFirstInput } from '~/components/drawers/useFocusTrap'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { PlanBillingPeriodInfoSection } from '~/components/plans/drawers/common/PlanBillingPeriodInfoSection'
import { PlanFormProvider, usePlanFormContext } from '~/contexts/PlanFormContext'
import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { getCurrencySymbol } from '~/core/formats/intlFormatNumber'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

export interface SubscriptionFeeFormValues {
  amountCents: string
  payInAdvance: boolean
  trialPeriod: number
  invoiceDisplayName?: string
}

const subscriptionFeeSchema = z.object({
  amountCents: z.string().min(1, 'text_624ea7c29103fd010732ab7d'),
  payInAdvance: z.boolean(),
  trialPeriod: z.number(),
  invoiceDisplayName: z.string().optional(),
})

const SUBSCRIPTION_FEE_FORM_ID = 'subscription-fee-drawer-form'

const DEFAULT_VALUES: SubscriptionFeeFormValues = {
  amountCents: '',
  payInAdvance: false,
  trialPeriod: 0,
  invoiceDisplayName: undefined,
}

export interface SubscriptionFeeDrawerRef {
  openDrawer: (values: SubscriptionFeeFormValues) => void
  closeDrawer: () => void
}

interface SubscriptionFeeDrawerProps {
  canBeEdited?: boolean
  isInSubscriptionForm?: boolean
  subscriptionFormType?: keyof typeof FORM_TYPE_ENUM
  isEdition?: boolean
  onSave: (values: SubscriptionFeeFormValues) => void | boolean | Promise<void | boolean>
}

export const SubscriptionFeeDrawer = forwardRef<
  SubscriptionFeeDrawerRef,
  SubscriptionFeeDrawerProps
>(({ canBeEdited, isInSubscriptionForm, subscriptionFormType, isEdition, onSave }, ref) => {
  const { translate } = useInternationalization()
  const { currency, interval } = usePlanFormContext()
  const subscriptionFeeDrawer = useFormDrawer()

  const form = useAppForm({
    defaultValues: DEFAULT_VALUES,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: subscriptionFeeSchema,
    },
    onSubmit: async ({ value }) => {
      const result = await onSave({
        ...value,
        trialPeriod: Number(value.trialPeriod) || 0,
        invoiceDisplayName: value.invoiceDisplayName || undefined,
      })

      if (result !== false) {
        subscriptionFeeDrawer.close()
      }
    },
  })

  const openSubscriptionFeeDrawer = () => {
    subscriptionFeeDrawer.open({
      title: translate('text_642d5eb2783a2ad10d670336'),
      form: { id: SUBSCRIPTION_FEE_FORM_ID, submit: form.handleSubmit },
      closeOnSubmitSuccess: false,
      shouldPromptOnClose: () => form.state.isDirty,
      onClose: () => form.reset(),
      onEntered: focusFirstInput,
      children: (
        <PlanFormProvider currency={currency} interval={interval}>
          <CenteredPage.SectionWrapper>
            <CenteredPage.PageTitle
              title={translate('text_642d5eb2783a2ad10d670336')}
              description={translate('text_1770063200028xc3xmcvi7bw')}
            />

            <CenteredPage.SubsectionWrapper>
              <CenteredPage.PageSection>
                <CenteredPage.PageSectionTitle title={translate('text_177196303346655qni6k55jr')} />

                <form.AppField name="amountCents">
                  {(field) => (
                    <field.AmountInputField
                      currency={currency}
                      beforeChangeFormatter={['positiveNumber']}
                      label={translate('text_624453d52e945301380e49b6')}
                      InputProps={{
                        startAdornment: (
                          <InputAdornment position="start">
                            {getCurrencySymbol(currency || CurrencyEnum.Usd)}
                          </InputAdornment>
                        ),
                      }}
                    />
                  )}
                </form.AppField>
              </CenteredPage.PageSection>

              <CenteredPage.PageSection>
                <CenteredPage.PageSectionTitle title={translate('text_17423672025282dl7iozy1ru')} />

                <form.AppField name="invoiceDisplayName">
                  {(field) => (
                    <field.TextInputField
                      label={translate('text_65a6b4e2cb38d9b70ec53d39')}
                      description={translate('text_1771963033467yduu33x3qw9')}
                      placeholder={translate('text_65a6b4e2cb38d9b70ec53d41')}
                    />
                  )}
                </form.AppField>

                <PlanBillingPeriodInfoSection />

                <form.AppField name="payInAdvance">
                  {(field) => (
                    <field.RadioGroupField
                      disabled={isInSubscriptionForm || (isEdition && !canBeEdited)}
                      label={translate('text_6682c52081acea90520743a8')}
                      description={translate('text_6682c52081acea90520743aa')}
                      optionLabelVariant="body"
                      options={[
                        {
                          label: translate('text_6682c52081acea90520743ac'),
                          value: false,
                        },
                        {
                          label: translate('text_6682c52081acea90520743ae'),
                          value: true,
                        },
                      ]}
                    />
                  )}
                </form.AppField>

                <form.AppField
                  name="trialPeriod"
                  listeners={{
                    onChange: ({ value, fieldApi }) => {
                      if (typeof value !== 'number' || Number.isNaN(value)) {
                        fieldApi.setValue(0)
                      }
                    },
                  }}
                >
                  {(field) => (
                    <field.TextInputField
                      beforeChangeFormatter={['positiveNumber', 'int']}
                      className="flex-1"
                      description={translate('text_6661fc17337de3591e29e403')}
                      disabled={
                        subscriptionFormType === FORM_TYPE_ENUM.edition ||
                        (isEdition && !canBeEdited)
                      }
                      label={translate('text_624453d52e945301380e49c2')}
                      placeholder={translate('text_62824f0e5d93bc008d268d00')}
                      InputProps={{
                        endAdornment: (
                          <InputAdornment position="end">
                            {translate('text_624453d52e945301380e49c6')}
                          </InputAdornment>
                        ),
                      }}
                    />
                  )}
                </form.AppField>
              </CenteredPage.PageSection>
            </CenteredPage.SubsectionWrapper>
          </CenteredPage.SectionWrapper>
        </PlanFormProvider>
      ),
      mainAction: (
        <form.AppForm>
          <form.SubmitButton dataTest="subscription-fee-drawer-save">
            {translate('text_17295436903260tlyb1gp1i7')}
          </form.SubmitButton>
        </form.AppForm>
      ),
    })
  }

  useImperativeHandle(ref, () => ({
    openDrawer: (values: SubscriptionFeeFormValues) => {
      form.reset(
        {
          ...values,
          trialPeriod: values.trialPeriod ?? 0,
        },
        { keepDefaultValues: true },
      )

      openSubscriptionFeeDrawer()
    },
    closeDrawer: () => {
      subscriptionFeeDrawer.close()
    },
  }))

  return null
})

SubscriptionFeeDrawer.displayName = 'SubscriptionFeeDrawer'
