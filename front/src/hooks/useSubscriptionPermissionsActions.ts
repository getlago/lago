import { StatusTypeEnum } from '~/generated/graphql'
import { usePermissions } from '~/hooks/usePermissions'

export const useSubscriptionPermissionsActions = () => {
  const { hasPermissions } = usePermissions()

  /**
   * Checks if a subscription status allows editing (not terminated, canceled, or incomplete).
   */
  const isStatusEditable = (status: StatusTypeEnum | null | undefined): boolean => {
    if (!status) return false

    return (
      status !== StatusTypeEnum.Terminated &&
      status !== StatusTypeEnum.Canceled &&
      status !== StatusTypeEnum.Incomplete
    )
  }

  /**
   * Checks if a subscription can be edited based on both permissions and status.
   */
  const canEditSubscription = (status: StatusTypeEnum | null | undefined): boolean => {
    return hasPermissions(['subscriptionsUpdate']) && isStatusEditable(status)
  }

  return {
    isStatusEditable,
    canEditSubscription,
  }
}
