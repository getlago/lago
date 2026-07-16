import { gql, useApolloClient } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { evictFromCache } from '~/core/apolloClient/evictFromCache'
import {
  DeleteXeroIntegrationDialogFragment,
  GetXeroIntegrationsListDocument,
  useDestroyNangoIntegrationMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteXeroIntegrationDialog on XeroIntegration {
    id
    name
  }

  mutation destroyNangoIntegration($input: DestroyIntegrationInput!) {
    destroyIntegration(input: $input) {
      id
    }
  }
`

type TDeleteXeroIntegrationDialogProps = {
  provider: DeleteXeroIntegrationDialogFragment | null
  callback?: () => void
}

export const useDeleteXeroIntegrationDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const client = useApolloClient()

  const [deleteXero] = useDestroyNangoIntegrationMutation()

  const openDeleteXeroIntegrationDialog = ({
    provider,
    callback,
  }: TDeleteXeroIntegrationDialogProps) => {
    centralizedDialog.open({
      title: translate('text_658461066530343fe1808cd7', { name: provider?.name }),
      description: translate('text_6672ebb8b1b50be550eccada'),
      colorVariant: 'danger',
      actionText: translate('text_645d071272418a14c1c76a81'),
      onAction: async () => {
        const result = await deleteXero({
          variables: { input: { id: provider?.id as string } },
        })

        const destroyedId = result.data?.destroyIntegration?.id

        if (destroyedId) {
          evictFromCache(client, {
            id: destroyedId,
            __typename: 'XeroIntegration',
            listFieldName: 'integrations',
            listQueryDocument: GetXeroIntegrationsListDocument,
          })

          callback?.()

          addToast({
            message: translate('text_661ff6e56ef7e1b7c542b2f9'),
            severity: 'success',
          })
        }
      },
    })
  }

  return { openDeleteXeroIntegrationDialog }
}
