import { StatusProps, StatusType } from '~/components/designSystem/Status'
import { StatusTypeEnum } from '~/generated/graphql'

export const subscriptionStatusMapping = (status?: StatusTypeEnum | null): StatusProps => {
  switch (status) {
    case StatusTypeEnum.Active:
      return {
        type: StatusType.success,
        label: 'active',
      }
    case StatusTypeEnum.Pending:
      return {
        type: StatusType.default,
        label: 'pending',
      }
    case StatusTypeEnum.Incomplete:
      return {
        type: StatusType.warning,
        label: 'incomplete',
      }
    case StatusTypeEnum.Canceled:
      return {
        type: StatusType.disabled,
        label: 'canceled',
      }
    case StatusTypeEnum.Terminated:
      return {
        type: StatusType.danger,
        label: 'terminated',
      }
    default:
      return {
        type: StatusType.default,
        label: 'pending',
      }
  }
}
