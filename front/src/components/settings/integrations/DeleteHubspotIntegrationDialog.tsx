import { gql, useApolloClient } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { evictFromCache } from '~/core/apolloClient/evictFromCache'
import {
  DeleteHubspotIntegrationDialogFragment,
  GetHubspotIntegrationsListDocument,
  useDestroyNangoIntegrationMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteHubspotIntegrationDialog on HubspotIntegration {
    id
    name
  }

  mutation destroyNangoIntegration($input: DestroyIntegrationInput!) {
    destroyIntegration(input: $input) {
      id
    }
  }
`

type OpenDeleteHubspotIntegrationDialogData = {
  provider: DeleteHubspotIntegrationDialogFragment | null
  callback?: () => void
}

export const useDeleteHubspotIntegrationDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const client = useApolloClient()

  const [deleteHubspot] = useDestroyNangoIntegrationMutation()

  const openDeleteHubspotIntegrationDialog = (data: OpenDeleteHubspotIntegrationDialogData) => {
    const provider = data.provider

    centralizedDialog.open({
      title: translate('text_658461066530343fe1808cd7', { name: provider?.name }),
      description: translate('text_1727453876790u9azb7rvhox'),
      actionText: translate('text_645d071272418a14c1c76a81'),
      colorVariant: 'danger',
      onAction: async () => {
        const res = await deleteHubspot({
          variables: { input: { id: provider?.id as string } },
        })

        const destroyedId = res.data?.destroyIntegration?.id

        if (destroyedId) {
          evictFromCache(client, {
            id: destroyedId,
            __typename: 'HubspotIntegration',
            listFieldName: 'integrations',
            listQueryDocument: GetHubspotIntegrationsListDocument,
          })

          data.callback?.()

          addToast({
            message: translate('text_661ff6e56ef7e1b7c542b2f9'),
            severity: 'success',
          })
        }
      },
    })
  }

  return { openDeleteHubspotIntegrationDialog }
}
