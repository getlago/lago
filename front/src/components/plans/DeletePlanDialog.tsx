import { gql } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { DeletePlanDialogFragment, useDeletePlanMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeletePlanDialog on Plan {
    id
    name
    draftInvoicesCount
    activeSubscriptionsCount
  }

  mutation deletePlan($input: DestroyPlanInput!) {
    destroyPlan(input: $input) {
      id
    }
  }
`

type DeletePlanDialogProps = {
  plan: DeletePlanDialogFragment
  callback?: () => void
}

export const useDeletePlanDialog = () => {
  const { translate } = useInternationalization()

  const [deletePlan] = useDeletePlanMutation({
    refetchQueries: ['plans'],
  })

  const centralizedDialog = useCentralizedDialog()

  const openDeletePlanDialog = ({ plan, callback }: DeletePlanDialogProps) => {
    const { id = '', name = '', draftInvoicesCount = 0, activeSubscriptionsCount = 0 } = plan || {}

    let usedObject1 = translate('text_63d18d34f90cc83a038f843b', { count: 0 }, 0)

    if (activeSubscriptionsCount > 0) {
      usedObject1 = translate(
        'text_63d18d34f90cc83a038f843b',
        { count: activeSubscriptionsCount },
        activeSubscriptionsCount,
      )
    } else if (draftInvoicesCount > 0) {
      usedObject1 = translate(
        'text_63d18d3edaed7e11710b4d25',
        { count: draftInvoicesCount },
        draftInvoicesCount,
      )
    }

    const description = translate(
      'text_63d18bdc54f8380e7a97351a',
      draftInvoicesCount > 0 && activeSubscriptionsCount > 0
        ? {
            usedObject1: translate(
              'text_63d18d34f90cc83a038f843b',
              { count: activeSubscriptionsCount },
              activeSubscriptionsCount,
            ),
            usedObject2: translate(
              'text_63d18d3edaed7e11710b4d25',
              { count: draftInvoicesCount },
              draftInvoicesCount,
            ),
          }
        : {
            usedObject1,
          },
      draftInvoicesCount > 0 && activeSubscriptionsCount > 0 ? 2 : 0,
    )

    centralizedDialog.open({
      title: translate('text_625fd165963a7b00c8f59797', {
        planName: name,
      }),
      description,
      colorVariant: 'danger',
      actionText: translate('text_625fd165963a7b00c8f597b5'),
      onAction: async () => {
        const result = await deletePlan({
          variables: { input: { id } },
        })

        if (result.data?.destroyPlan) {
          addToast({
            message: translate('text_625fd165963a7b00c8f59879'),
            severity: 'success',
          })

          callback?.()
        }
      },
    })
  }

  return { openDeletePlanDialog }
}
