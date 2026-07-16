import { useMemo } from 'react'

import { PaymentMethodTypeEnum } from '~/generated/graphql'
import { PaymentMethodItem, PaymentMethodList } from '~/hooks/customer/usePaymentMethodsList'

import { SelectedPaymentMethod } from './types'

export interface DisplayedPaymentMethod {
  paymentMethod: PaymentMethodItem | null
  isManual: boolean
  isInherited: boolean
}

export const useDisplayedPaymentMethod = (
  selectedPaymentMethod: SelectedPaymentMethod,
  paymentMethodsList?: PaymentMethodList,
): DisplayedPaymentMethod => {
  const defaultPaymentMethod = useMemo(() => {
    return paymentMethodsList?.find((pm) => pm.isDefault && !pm.deletedAt)
  }, [paymentMethodsList])

  const displayedPaymentMethod = useMemo((): DisplayedPaymentMethod => {
    // If there's a payment method from the Form props, use it
    if (selectedPaymentMethod?.paymentMethodId) {
      const pm = paymentMethodsList?.find(
        (paymentMethod) =>
          paymentMethod.id === selectedPaymentMethod.paymentMethodId && !paymentMethod.deletedAt,
      )

      if (pm) {
        return { paymentMethod: pm, isManual: false, isInherited: false }
      }
    }

    // If manual type is explicitly set
    if (selectedPaymentMethod?.paymentMethodType === PaymentMethodTypeEnum.Manual) {
      return { paymentMethod: null, isManual: true, isInherited: false }
    }

    // Otherwise, fallback to default or manual
    if (defaultPaymentMethod) {
      return { paymentMethod: defaultPaymentMethod, isManual: false, isInherited: true }
    }

    return { paymentMethod: null, isManual: true, isInherited: true }
  }, [selectedPaymentMethod, paymentMethodsList, defaultPaymentMethod])

  return displayedPaymentMethod
}
