import { PaymentProviderChip } from '~/components/PaymentProviderChip'
import { PaymentMethodItem } from '~/hooks/customer/usePaymentMethodsList'

import { PaymentMethodDetails } from './PaymentMethodDetails'

import { Typography } from '../designSystem/Typography'

export const DEFAULT_BADGE_TEST_ID = 'default-badge'

type PaymentMethodData = Pick<
  PaymentMethodItem,
  | 'createdAt'
  | 'details'
  | 'isDefault'
  | 'paymentProviderType'
  | 'paymentProviderName'
  | 'providerMethodId'
>

interface PaymentMethodInfoProps {
  paymentMethod: PaymentMethodData
  showExpiration: boolean
  showProviderAvatar: boolean
}

export const PaymentMethodInfo = ({
  paymentMethod,
  showExpiration,
  showProviderAvatar,
}: PaymentMethodInfoProps): JSX.Element => {
  const {
    createdAt,
    details,
    isDefault,
    paymentProviderType,
    paymentProviderName,
    providerMethodId,
  } = paymentMethod

  return (
    <div className="flex flex-1 flex-col">
      <PaymentMethodDetails
        details={details}
        createdAt={createdAt}
        isDefault={isDefault}
        showExpiration={showExpiration}
        className="gap-1"
        data-test={DEFAULT_BADGE_TEST_ID}
      />

      {/* PSP INFO */}
      <div className="flex items-center gap-1">
        {paymentProviderType && (
          <PaymentProviderChip
            paymentProvider={paymentProviderType}
            label={paymentProviderName}
            className="text-xs"
            textVariant="caption"
            textColor="grey500"
            showAvatar={showProviderAvatar}
          />
        )}
        {(paymentProviderType || paymentProviderName) && providerMethodId && (
          <Typography variant="caption" className="text-grey-500">
            {' • '}
          </Typography>
        )}
        {providerMethodId && (
          <Typography variant="caption" className="text-grey-500">
            {providerMethodId}
          </Typography>
        )}
      </div>
    </div>
  )
}
