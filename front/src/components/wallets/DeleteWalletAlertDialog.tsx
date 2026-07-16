import { gql } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { useDestroyWalletAlertMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteWalletAlertDialog on Alert {
    id
  }

  mutation DestroyWalletAlert($input: DestroyCustomerWalletAlertInput!) {
    destroyCustomerWalletAlert(input: $input) {
      id
    }
  }
`

type DeleteWalletAlertDialogData = {
  alertId: string | undefined
  callback?: () => void
}

export const useDeleteWalletAlertDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()

  const [deleteWalletALert] = useDestroyWalletAlertMutation({
    refetchQueries: ['getWalletAlerts'],
  })

  const openDeleteWalletAlertDialog = (data: DeleteWalletAlertDialogData) => {
    centralizedDialog.open({
      title: translate('text_177305159320966u9a5j7yzj'),
      description: translate('text_1773051593209g9plvoxy8x3'),
      colorVariant: 'danger',
      actionText: translate('text_1773051593209rwm715tl9i6'),
      onAction: async () => {
        const result = await deleteWalletALert({
          variables: {
            input: {
              id: data.alertId ?? '',
            },
          },
        })

        if (result.data?.destroyCustomerWalletAlert?.id) {
          data.callback?.()

          addToast({
            message: translate('text_17730638681767dkaxbmgifz'),
            severity: 'success',
          })
        }
      },
    })
  }

  return { openDeleteWalletAlertDialog }
}
