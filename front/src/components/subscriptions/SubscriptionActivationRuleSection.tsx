import InputAdornment from '@mui/material/InputAdornment'
import { useStore } from '@tanstack/react-form'
import { useEffect, useMemo } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { useDisplayedPaymentMethod } from '~/components/paymentMethodSelection/useDisplayedPaymentMethod'
import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { ActivationRuleFormTypeEnum } from '~/core/constants/subscriptionActivationRules'
import { StatusTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePaymentMethodsList } from '~/hooks/customer/usePaymentMethodsList'
import { withForm } from '~/hooks/forms/useAppform'

import {
  buildSubscriptionDefaultValues,
  SubscriptionFormType,
} from './form/buildSubscriptionDefaultValues'

interface SubscriptionActivationRuleSectionExtraProps {
  customerExternalId?: string | null
  formType: SubscriptionFormType
  subscriptionStatus?: StatusTypeEnum | null
}

export const SUBSCRIPTION_ACTIVATION_RULE_SECTION_TEST_ID = 'subscription-activation-rule-section'
export const SUBSCRIPTION_ACTIVATION_TIMEOUT_INPUT_TEST_ID = 'subscription-activation-timeout-input'

const TYPING_PLACEHOLDER_DATE = '2026-01-01'

const subscriptionActivationRuleDefaultProps: SubscriptionActivationRuleSectionExtraProps = {
  customerExternalId: undefined,
  formType: FORM_TYPE_ENUM.creation,
  subscriptionStatus: undefined,
}

export const SubscriptionActivationRuleSection = withForm({
  defaultValues: buildSubscriptionDefaultValues(
    undefined,
    FORM_TYPE_ENUM.creation,
    TYPING_PLACEHOLDER_DATE,
  ),
  props: subscriptionActivationRuleDefaultProps,
  render: function SubscriptionActivationRuleSectionRender({
    form,
    customerExternalId,
    formType,
    subscriptionStatus,
  }) {
    const { translate } = useInternationalization()

    const paymentMethod = useStore(form.store, (state) => state.values.paymentMethod)
    const activationRuleType = useStore(form.store, (state) => state.values.activationRuleType)

    const {
      data: paymentMethodsList,
      loading: paymentMethodsLoading,
      error: paymentMethodsError,
    } = usePaymentMethodsList({
      externalCustomerId: customerExternalId || '',
      withDeleted: false,
      skip: !customerExternalId,
    })

    const displayedPaymentMethod = useDisplayedPaymentMethod(paymentMethod, paymentMethodsList)
    const hasResolvedPaymentMethods = !paymentMethodsLoading || paymentMethodsError

    const isPaymentActivationUnavailable =
      !customerExternalId || !hasResolvedPaymentMethods || displayedPaymentMethod.isManual

    const isEditable = useMemo(() => {
      return (
        formType === FORM_TYPE_ENUM.creation ||
        formType === FORM_TYPE_ENUM.upgradeDowngrade ||
        (formType === FORM_TYPE_ENUM.edition && subscriptionStatus === StatusTypeEnum.Pending)
      )
    }, [formType, subscriptionStatus])

    useEffect(() => {
      // Only auto-correct once payment methods have resolved. While they are still
      // loading, `isPaymentActivationUnavailable` is transiently true (no list yet →
      // manual fallback), which would otherwise clobber a loaded "on payment" selection
      // back to "immediately" before the data finishes loading.
      if (
        hasResolvedPaymentMethods &&
        isPaymentActivationUnavailable &&
        activationRuleType === ActivationRuleFormTypeEnum.OnPayment
      ) {
        form.setFieldValue('activationRuleType', ActivationRuleFormTypeEnum.Immediately)
      }
    }, [activationRuleType, form, hasResolvedPaymentMethods, isPaymentActivationUnavailable])

    return (
      <div className="flex flex-col gap-6" data-test={SUBSCRIPTION_ACTIVATION_RULE_SECTION_TEST_ID}>
        <div className="flex flex-col gap-2">
          <CenteredPage.SubsectionTitle title={translate('text_17798820214653y71jn6hh2s')} />
          <form.AppField name="activationRuleType">
            {(field) => (
              <field.RadioGroupField
                optionsGapSpacing={3}
                optionLabelVariant="body"
                disabled={!isEditable || isPaymentActivationUnavailable}
                options={[
                  {
                    value: ActivationRuleFormTypeEnum.Immediately,
                    label: translate('text_1779882021465z73glv4ru42'),
                    sublabel: translate('text_1779882021465b4cvr8upxvp'),
                  },
                  {
                    value: ActivationRuleFormTypeEnum.OnPayment,
                    label: translate('text_17798820214653lthtne1wrc'),
                    sublabel: translate('text_17798820214653qiqu79w4hp'),
                  },
                ]}
              />
            )}
          </form.AppField>
        </div>

        {activationRuleType === ActivationRuleFormTypeEnum.OnPayment && (
          <form.AppField name="activationRuleTimeoutHours">
            {(field) => (
              <field.TextInputField
                data-test={SUBSCRIPTION_ACTIVATION_TIMEOUT_INPUT_TEST_ID}
                disabled={!isEditable || isPaymentActivationUnavailable}
                label={translate('text_1779882021465u30p886nhn9')}
                description={translate('text_1779882021466w4zlmq76sk3')}
                beforeChangeFormatter={['positiveNumber', 'int']}
                placeholder="0"
                InputProps={{
                  endAdornment: (
                    <InputAdornment position="end">
                      <Typography variant="caption" color="grey600">
                        {translate('text_1779882021466zksievk0gq7')}
                      </Typography>
                    </InputAdornment>
                  ),
                }}
              />
            )}
          </form.AppField>
        )}
      </div>
    )
  },
})
