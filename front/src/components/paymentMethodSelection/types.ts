import { ComboBoxProps } from '~/components/form/ComboBox/types'
import { PaymentMethodReferenceInput, PaymentMethodTypeEnum } from '~/generated/graphql'
import { PaymentMethodList } from '~/hooks/customer/usePaymentMethodsList'

import { ViewTypeEnum } from '../paymentMethodsInvoiceSettings/types'

export type SelectedPaymentMethod = PaymentMethodReferenceInput | null | undefined

export enum PaymentMethodBehavior {
  FALLBACK = 'fallback',
  SPECIFIC = 'specific',
  MANUAL = 'manual',
}

export const deriveBehavior = (value?: SelectedPaymentMethod): PaymentMethodBehavior => {
  if (value?.paymentMethodType === PaymentMethodTypeEnum.Manual) return PaymentMethodBehavior.MANUAL
  if (value?.paymentMethodId) return PaymentMethodBehavior.SPECIFIC

  return PaymentMethodBehavior.FALLBACK
}

export interface PaymentMethodComboBoxProps {
  paymentMethodsList?: PaymentMethodList
  selectedPaymentMethod: SelectedPaymentMethod
  setSelectedPaymentMethod: (value: SelectedPaymentMethod) => void
  externalCustomerId?: string
  className?: string
  disabled?: boolean
  name?: string
  error?: string
  PopperProps?: ComboBoxProps['PopperProps']
}

export interface PaymentMethodSelectionProps {
  externalCustomerId: string
  selectedPaymentMethod: SelectedPaymentMethod
  setSelectedPaymentMethod: (value: SelectedPaymentMethod) => void
  viewType: ViewTypeEnum
  className?: string
  disabled?: boolean
}
