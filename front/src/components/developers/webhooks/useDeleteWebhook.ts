import { gql } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { useDeleteWebhookMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  mutation deleteWebhook($input: DestroyWebhookEndpointInput!) {
    destroyWebhookEndpoint(input: $input) {
      id
    }
  }
`

export const useDeleteWebhook = () => {
  const { translate } = useInternationalization()
  const dialog = useCentralizedDialog()
  const [deleteWebhook] = useDeleteWebhookMutation({
    onCompleted(res) {
      if (!!res.destroyWebhookEndpoint) {
        addToast({
          message: translate('text_6271200984178801ba8bdf6c'),
          severity: 'success',
        })
      }
    },
    refetchQueries: ['getWebhookList'],
  })

  return {
    openDialog: (webhookId: string, { onSuccess }: { onSuccess?: () => void } = {}) => {
      dialog.open({
        title: translate('text_6271200984178801ba8bdeb2'),
        description: translate('text_6271200984178801ba8bded2'),
        onAction: async () => {
          await deleteWebhook({
            variables: { input: { id: webhookId } },
          })

          onSuccess?.()

          return { reason: 'success' }
        },
        actionText: translate('text_6271200984178801ba8bdf0c'),
        colorVariant: 'danger',
      })
    },
  }
}
