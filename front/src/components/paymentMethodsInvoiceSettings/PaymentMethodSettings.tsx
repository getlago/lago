import { PaymentMethodSelection } from '~/components/paymentMethodSelection/PaymentMethodSelection'
import { SelectedPaymentMethod } from '~/components/paymentMethodSelection/types'
import { getFieldPath, getFieldValue } from '~/core/form/fieldPathUtils'

import { SettingsComponentProps, ViewTypeEnum } from './types'

// Standalone payment-method settings: renders only when the customer has an
// externalId (the payment methods list is keyed by external id). Owns the
// `paymentMethod` form field via the optional `formFieldBasePath` adapter.
export const PaymentMethodSettings = <T extends ViewTypeEnum>({
  customer,
  form,
  viewType,
  formFieldBasePath,
}: SettingsComponentProps<T>) => {
  const externalId = customer?.externalId

  if (!externalId) return null

  return (
    <PaymentMethodSelection
      viewType={viewType}
      externalCustomerId={externalId}
      selectedPaymentMethod={getFieldValue<SelectedPaymentMethod>(
        'paymentMethod',
        form.values,
        formFieldBasePath,
      )}
      setSelectedPaymentMethod={(item) => {
        form.setFieldValue(getFieldPath('paymentMethod', formFieldBasePath), item)
      }}
    />
  )
}
