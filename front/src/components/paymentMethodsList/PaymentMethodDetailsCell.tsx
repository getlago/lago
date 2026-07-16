import { Icon } from 'lago-design-system'

import { PaymentMethodInfo } from '~/components/paymentMethodSelection/PaymentMethodInfo'
import { PaymentMethodItem } from '~/hooks/customer/usePaymentMethodsList'

interface PaymentMethodDetailsCellProps {
  item: PaymentMethodItem
}

export const PaymentMethodDetailsCell = ({ item }: PaymentMethodDetailsCellProps): JSX.Element => {
  return (
    <div className="flex items-center gap-3">
      {/* ICON */}
      <div className="flex size-10 items-center justify-center rounded-xl bg-grey-100">
        <Icon name="coin-dollar" color="dark" />
      </div>

      <PaymentMethodInfo paymentMethod={item} showExpiration showProviderAvatar />
    </div>
  )
}
