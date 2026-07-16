import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { deserializeActivationRules } from '~/core/serializers'
import { SubscriptionFormValues } from '~/formValidation/subscriptionFormSchema'
import { BillingTimeEnum, SubscriptionForSubscriptionEditFormFragment } from '~/generated/graphql'

export type SubscriptionDefaultsSource =
  SubscriptionForSubscriptionEditFormFragment | null | undefined

export type SubscriptionFormType = keyof typeof FORM_TYPE_ENUM

export const buildSubscriptionDefaultValues = (
  subscription: SubscriptionDefaultsSource,
  formType: SubscriptionFormType,
  currentDate: string,
): SubscriptionFormValues => {
  const activationRuleValues = deserializeActivationRules(subscription?.activationRules)

  return {
    planId:
      subscription?.plan?.id && formType !== FORM_TYPE_ENUM.upgradeDowngrade
        ? subscription.plan.id
        : '',
    name:
      subscription?.name && formType !== FORM_TYPE_ENUM.upgradeDowngrade ? subscription.name : '',
    externalId: subscription?.externalId || '',
    subscriptionAt: subscription?.subscriptionAt || currentDate,
    endingAt: subscription?.endingAt || undefined,
    billingTime: subscription?.billingTime || BillingTimeEnum.Calendar,
    paymentMethod: {
      paymentMethodType: subscription?.paymentMethodType,
      paymentMethodId: subscription?.paymentMethod?.id,
    },
    invoiceCustomSection: {
      invoiceCustomSections: subscription?.selectedInvoiceCustomSections || [],
      skipInvoiceCustomSections: subscription?.skipInvoiceCustomSections || false,
    },
    consolidateInvoice: subscription?.consolidateInvoice ?? true,
    ...activationRuleValues,
  }
}
