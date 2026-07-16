import { StatusProps, StatusType } from '~/components/designSystem/Status'
import { OrderFormStatusEnum } from '~/generated/graphql'

export const getOrderFormStatusMapping = (
  status: OrderFormStatusEnum,
  translate: (key: string) => string,
): Pick<StatusProps, 'type' | 'label'> => {
  switch (status) {
    case OrderFormStatusEnum.Generated:
      return { type: StatusType.warning, label: translate('text_17766979384805q6wx9it6wa') }
    case OrderFormStatusEnum.Signed:
      return { type: StatusType.success, label: translate('text_1776697938480b1fi7wqtzyi') }
    case OrderFormStatusEnum.Voided:
      return { type: StatusType.disabled, label: translate('text_1776697938480hzc1xsmmpez') }
    case OrderFormStatusEnum.Expired:
      return { type: StatusType.disabled, label: translate('text_1776697938480ap28ussl837') }
    default:
      return { type: StatusType.outline, label: status }
  }
}
