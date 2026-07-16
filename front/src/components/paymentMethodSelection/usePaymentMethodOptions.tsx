import { useMemo } from 'react'

import { formatPaymentMethodDetails } from '~/core/formats/formatPaymentMethodDetails'
import { PaymentMethodTypeEnum } from '~/generated/graphql'
import { TranslateFunc, useInternationalization } from '~/hooks/core/useInternationalization'
import { PaymentMethodItem, PaymentMethodList } from '~/hooks/customer/usePaymentMethodsList'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

import { PaymentMethodInfo } from './PaymentMethodInfo'

export interface PaymentMethodOption {
  value: string
  label: string
  labelNode: React.ReactNode
  isDefault?: boolean
  type: PaymentMethodTypeEnum
}

const mapPaymentMethodItemToOption = (
  paymentMethod: PaymentMethodItem,
  translate: TranslateFunc,
  intlFormatDateTimeOrgaTZ: (date: string) => { date: string; time: string; timezone: string },
): PaymentMethodOption => {
  const { id, createdAt, details, isDefault } = paymentMethod
  const { type, brand, last4 } = details || {}

  const baseLabel =
    formatPaymentMethodDetails({ type, brand, last4 }) ||
    translate('text_1771854080250kv3j6oa9nxj', {
      date: intlFormatDateTimeOrgaTZ(createdAt).date,
    })
  const label = isDefault
    ? `${baseLabel} (${translate('text_65281f686a80b400c8e2f6d1')})`
    : baseLabel

  return {
    value: id,
    label,
    type: PaymentMethodTypeEnum.Provider,
    labelNode: (
      <PaymentMethodInfo
        paymentMethod={paymentMethod}
        showExpiration={false}
        showProviderAvatar={false}
      />
    ),
    ...(isDefault && { isDefault: true }),
  }
}

export const usePaymentMethodOptions = (
  paymentMethodsList: PaymentMethodList | undefined,
): PaymentMethodOption[] => {
  const { translate } = useInternationalization()
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()

  return useMemo(() => {
    if (!paymentMethodsList) return []

    const activePaymentMethods = paymentMethodsList.filter((pm) => !pm.deletedAt)

    return activePaymentMethods.reduce((acc, paymentMethod) => {
      const option = mapPaymentMethodItemToOption(
        paymentMethod,
        translate,
        intlFormatDateTimeOrgaTZ,
      )

      // Insert default at the beginning of the options
      return paymentMethod.isDefault ? [option, ...acc] : [...acc, option]
    }, [] as PaymentMethodOption[])
  }, [paymentMethodsList, translate, intlFormatDateTimeOrgaTZ])
}
