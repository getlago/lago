import { DetailsPage } from '~/components/layouts/DetailsPage'
import { formatPaymentMethodDetails } from '~/core/formats/formatPaymentMethodDetails'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePaymentMethodsList } from '~/hooks/customer/usePaymentMethodsList'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

import { SelectedPaymentMethod } from '../paymentMethodSelection/types'
import { useDisplayedPaymentMethod } from '../paymentMethodSelection/useDisplayedPaymentMethod'

export const MANUAL_PAYMENT_METHOD_TEST_ID = 'manual-payment-method'
export const INHERITED_BADGE_TEST_ID = 'inherited-badge'

interface SubscriptionPaymentMethodDetailsProps {
  selectedPaymentMethod?: SelectedPaymentMethod
  externalCustomerId?: string
  className?: string
}

// Read-only display of the subscription's resolved payment method (specific
// provider method, manual, or inherited customer default). Returns null when
// there's nothing to show.
export const SubscriptionPaymentMethodDetails = ({
  selectedPaymentMethod,
  externalCustomerId,
  className,
}: SubscriptionPaymentMethodDetailsProps): JSX.Element | null => {
  const { translate } = useInternationalization()
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()

  const { data: paymentMethodsList } = usePaymentMethodsList({
    externalCustomerId: externalCustomerId || '',
    withDeleted: false,
  })

  const displayedPaymentMethod = useDisplayedPaymentMethod(
    selectedPaymentMethod,
    paymentMethodsList,
  )

  let formattedPaymentMethodDetails = ''

  if (displayedPaymentMethod.isManual) {
    formattedPaymentMethodDetails = translate('text_173799550683709p2rqkoqd5')
  } else if (displayedPaymentMethod.paymentMethod) {
    formattedPaymentMethodDetails =
      formatPaymentMethodDetails(displayedPaymentMethod.paymentMethod.details) ||
      translate('text_1771854080250kv3j6oa9nxj', {
        date: intlFormatDateTimeOrgaTZ(displayedPaymentMethod.paymentMethod.createdAt).date,
      })
  }

  const inheritedText = displayedPaymentMethod.isInherited
    ? ` (${translate('text_1764327933607jgtpungo2pp')})`
    : ''

  if (!formattedPaymentMethodDetails) {
    return null
  }

  return (
    <DetailsPage.InfoGridItem
      className={className}
      label={translate('text_17440371192353kif37ol194')}
      value={
        <span>
          {displayedPaymentMethod.isManual ? (
            <span data-test={MANUAL_PAYMENT_METHOD_TEST_ID}>{formattedPaymentMethodDetails}</span>
          ) : (
            formattedPaymentMethodDetails
          )}
          {displayedPaymentMethod.isInherited && (
            <span data-test={INHERITED_BADGE_TEST_ID}>{inheritedText}</span>
          )}
        </span>
      }
    />
  )
}
