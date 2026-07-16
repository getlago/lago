import { addToast } from '~/core/apolloClient'
import { LagoApiError, UpdatePlanMutation, useUpdatePlanMutation } from '~/generated/graphql'

type UpdatePlanResult = NonNullable<UpdatePlanMutation['updatePlan']>

type UsePlanUpdateOptions = {
  onSuccess?: (updatePlan: UpdatePlanResult) => void
}

export const usePlanUpdate = ({ onSuccess }: UsePlanUpdateOptions = {}) => {
  const [update, { error }] = useUpdatePlanMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted({ updatePlan }) {
      if (updatePlan) {
        addToast({ severity: 'success', translateKey: 'text_625fd165963a7b00c8f598a0' })
        onSuccess?.(updatePlan)
      }
    },
  })

  return { update, error }
}
