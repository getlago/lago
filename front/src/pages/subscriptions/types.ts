import { InvoiceCustomSectionInput } from '~/components/invoceCustomFooter/types'
import { SelectedPaymentMethod } from '~/components/paymentMethodSelection/types'
import { ActivationRuleFormTypeEnum } from '~/core/constants/subscriptionActivationRules'
import { CreateSubscriptionInput } from '~/generated/graphql'

export type SubscriptionFormInput = Omit<
  CreateSubscriptionInput,
  'activationRules' | 'customerId' | 'paymentMethod'
> & {
  activationRuleType?: ActivationRuleFormTypeEnum
  activationRuleTimeoutHours?: string
  paymentMethod?: SelectedPaymentMethod
  invoiceCustomSection?: InvoiceCustomSectionInput
}
