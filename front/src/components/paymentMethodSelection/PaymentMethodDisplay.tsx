import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { PaymentMethodDetails } from './PaymentMethodDetails'
import { DisplayedPaymentMethod } from './useDisplayedPaymentMethod'

export const MANUAL_PAYMENT_METHOD_TEST_ID = 'manual-payment-method'
export const INHERITED_BADGE_TEST_ID = 'inherited-badge'

interface PaymentMethodDisplayProps {
  displayedPaymentMethod: DisplayedPaymentMethod
}

export const PaymentMethodDisplay = ({
  displayedPaymentMethod,
}: PaymentMethodDisplayProps): JSX.Element | null => {
  const { translate } = useInternationalization()
  const { paymentMethod, isManual, isInherited } = displayedPaymentMethod

  const inheritedComp = () => {
    return (
      <Typography variant="body" color="grey700" data-test={INHERITED_BADGE_TEST_ID}>
        ({translate('text_1764327933607jgtpungo2pp')})
      </Typography>
    )
  }

  if (isManual) {
    return (
      <div className="flex flex-col gap-1">
        <div className="flex items-center gap-2">
          <Typography
            variant="body"
            color="textSecondary"
            data-test={MANUAL_PAYMENT_METHOD_TEST_ID}
          >
            {translate('text_173799550683709p2rqkoqd5')}
          </Typography>
          {isInherited && inheritedComp()}
        </div>
      </div>
    )
  }

  if (!paymentMethod) return null

  return (
    <div className="flex flex-col gap-1">
      <div className="flex flex-wrap items-center gap-2">
        <PaymentMethodDetails
          details={paymentMethod.details}
          createdAt={paymentMethod.createdAt}
          isDefault={paymentMethod.isDefault}
        />
        {isInherited && inheritedComp()}
      </div>
    </div>
  )
}
