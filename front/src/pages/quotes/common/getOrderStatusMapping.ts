import { StatusProps, StatusType } from '~/components/designSystem/Status'
import { OrderStatusEnum } from '~/generated/graphql'
import { TranslateFunc } from '~/hooks/core/useInternationalization'

export const getOrderStatusMapping = (
  status: OrderStatusEnum,
  translate: TranslateFunc,
): Pick<StatusProps, 'type' | 'label'> => {
  switch (status) {
    case OrderStatusEnum.Created:
      return { type: StatusType.warning, label: translate('text_1782392058759gdepj0tu2cn') }
    case OrderStatusEnum.Executed:
      return { type: StatusType.success, label: translate('text_17823920587590tcd0ckxjde') }
    default:
      return { type: StatusType.outline, label: status }
  }
}
