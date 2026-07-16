import { addToast } from '~/core/apolloClient'
import {
  LagoApiError,
  PlanOverridesInput,
  useUpdateSubscriptionMutation,
} from '~/generated/graphql'

type Args = {
  subscriptionId: string
}

export const useUpdateSubscriptionPlanOverride = ({ subscriptionId }: Args) => {
  const [updateSubscription] = useUpdateSubscriptionMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    refetchQueries: ['getSubscriptionForDetailsV2Plan'],
    awaitRefetchQueries: true,
    onCompleted(data) {
      if (data?.updateSubscription?.id) {
        addToast({ severity: 'success', translateKey: 'text_625fd165963a7b00c8f598a0' })
      }
    },
  })

  // Plan-level-only overrides. Charges are NEVER sent here - they go through
  // updateSubscriptionCharge. Omitting `charges` preserves existing overrides.
  const updatePlanOverride = async (planOverrides: PlanOverridesInput): Promise<boolean> => {
    // Report success only when the mutation returned the subscription. On error
    // (the error link resolves the result with `data: null`) return false so the
    // caller keeps the drawer open. Same success check across all sub-mode
    // mutation handlers.
    const { data } = await updateSubscription({
      variables: { input: { id: subscriptionId, planOverrides } },
    })

    return !!data?.updateSubscription?.id
  }

  return { updatePlanOverride }
}
