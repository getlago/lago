import { Coupon, CouponStatusEnum } from '~/generated/graphql'
import { usePermissions } from '~/hooks/usePermissions'

export const usePermissionsCouponActions = () => {
  const { hasPermissions } = usePermissions()

  const canCreate = (): boolean => {
    return hasPermissions(['couponsCreate'])
  }

  const canEdit = (): boolean => {
    return hasPermissions(['couponsUpdate'])
  }

  const canTerminate = (coupon: Pick<Coupon, 'status'>): boolean => {
    return coupon.status !== CouponStatusEnum.Terminated && hasPermissions(['couponsUpdate'])
  }

  const canDelete = (): boolean => {
    return hasPermissions(['couponsDelete'])
  }

  return {
    canCreate,
    canEdit,
    canTerminate,
    canDelete,
  }
}
