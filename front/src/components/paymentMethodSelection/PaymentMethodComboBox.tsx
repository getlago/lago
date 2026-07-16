import { ComboBox } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePaymentMethodsList } from '~/hooks/customer/usePaymentMethodsList'

import { PaymentMethodComboBoxProps } from './types'
import { usePaymentMethodOptions } from './usePaymentMethodOptions'

export const PaymentMethodComboBox = ({
  paymentMethodsList: paymentMethodsListProp,
  selectedPaymentMethod,
  setSelectedPaymentMethod,
  externalCustomerId,
  className,
  disabled = false,
  name = 'selectPaymentMethod',
  error,
  PopperProps,
}: PaymentMethodComboBoxProps) => {
  const { translate } = useInternationalization()

  const hasPaymentMethodsListProp = !!paymentMethodsListProp && paymentMethodsListProp.length > 0

  // If paymentMethodsListProp is provided, use it, otherwise fetch the payment methods list as fallback.
  const { data: fetchedPaymentMethodsList, loading } = usePaymentMethodsList({
    externalCustomerId,
    withDeleted: false,
    skip: hasPaymentMethodsListProp,
  })

  const paymentMethodsList = hasPaymentMethodsListProp
    ? paymentMethodsListProp
    : fetchedPaymentMethodsList

  const paymentMethodOptions = usePaymentMethodOptions(paymentMethodsList)

  const selectedValue = paymentMethodOptions.some(
    (option) => option.value === selectedPaymentMethod?.paymentMethodId,
  )
    ? selectedPaymentMethod?.paymentMethodId || undefined
    : undefined

  const onChange = (value: string) => {
    const selectedPaymentMethodOption = paymentMethodOptions.find(
      (option) => option.value === value,
    )

    setSelectedPaymentMethod({
      paymentMethodId: selectedPaymentMethodOption?.value || undefined,
      paymentMethodType: selectedPaymentMethodOption?.type || undefined,
    })
  }

  return (
    <ComboBox
      className={className}
      name={name}
      loading={loading}
      data={paymentMethodOptions}
      placeholder={translate('text_176433192749240fjx4tced9')}
      emptyText={translate('text_176432831893806loy6xo6qt')}
      value={selectedValue}
      onChange={onChange}
      disabled={disabled}
      error={error}
      sortValues={false}
      PopperProps={PopperProps}
    />
  )
}
