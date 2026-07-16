import { gql } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { useDestroySubscriptionAlertMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  mutation destroySubscriptionAlert($input: DestroySubscriptionAlertInput!) {
    destroySubscriptionAlert(input: $input) {
      id
    }
  }
`

type DeleteAlertDialogProps = {
  id: string
}

export const useDeleteAlertDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()

  const [destroyAlert] = useDestroySubscriptionAlertMutation({
    refetchQueries: ['getAlertsOfSubscription'],
  })

  const openDeleteAlertDialog = ({ id }: DeleteAlertDialogProps) => {
    centralizedDialog.open({
      title: translate('text_1746611635509m6xkucwbclx'),
      description: translate('text_1746611635509rkns7krj9zq'),
      colorVariant: 'danger',
      actionText: translate('text_6271200984178801ba8bdf0c'),
      onAction: async () => {
        const result = await destroyAlert({
          variables: { input: { id } },
        })

        if (result.data?.destroySubscriptionAlert?.id) {
          addToast({
            message: translate('text_1746611635508k9cmy2th6r1'),
            severity: 'success',
          })
        }
      },
    })
  }

  return { openDeleteAlertDialog }
}
