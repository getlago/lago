import { Status, StatusType } from '~/components/designSystem/Status'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { PaymentMethodItem } from '~/hooks/customer/usePaymentMethodsList'

interface PaymentMethodStatusCellProps {
  item: PaymentMethodItem
}

export const PaymentMethodStatusCell = ({ item }: PaymentMethodStatusCellProps): JSX.Element => {
  const { translate } = useInternationalization()

  const isDeleted = !!item?.deletedAt

  const status = {
    type: isDeleted ? StatusType.disabled : StatusType.success,
    label: isDeleted ? 'text_17625289719370dmo0r5s8c3' : 'text_624efab67eb2570101d1180e',
  }

  return <Status type={status.type} label={translate(status.label)} />
}
