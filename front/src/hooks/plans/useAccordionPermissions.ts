import { usePermissions } from '~/hooks/usePermissions'

export const useAccordionPermissions = (isInSubscriptionForm: boolean) => {
  const { hasPermissions } = usePermissions()

  if (isInSubscriptionForm) {
    // Sub plan tab mirrors the subscription edit form: edit only, no add/delete.
    // BE requires subscriptions:update for the override mutations.
    return {
      canCreate: false,
      canUpdate: hasPermissions(['subscriptionsUpdate']),
      canDelete: false,
    }
  }

  return {
    canCreate: hasPermissions(['plansCreate']),
    canUpdate: hasPermissions(['plansUpdate']),
    canDelete: hasPermissions(['plansDelete']),
  }
}
