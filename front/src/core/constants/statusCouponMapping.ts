import { StatusProps, StatusType } from '~/components/designSystem/Status'
import { CouponStatusEnum } from '~/generated/graphql'

export const couponStatusMapping = (type?: CouponStatusEnum | undefined): StatusProps => {
  switch (type) {
    case CouponStatusEnum.Active:
      return {
        type: StatusType.success,
        label: 'active',
      }
    default:
      return {
        type: StatusType.danger,
        label: 'terminated',
      }
  }
}
