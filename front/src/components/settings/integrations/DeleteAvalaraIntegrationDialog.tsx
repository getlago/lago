import { gql, useApolloClient } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { evictFromCache } from '~/core/apolloClient/evictFromCache'
import {
  DeleteAvalaraIntegrationDialogFragment,
  GetAvalaraIntegrationsListDocument,
  useDestroyNangoIntegrationMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteAvalaraIntegrationDialog on AvalaraIntegration {
    id
    name
  }

  mutation destroyAvalaraIntegration($input: DestroyIntegrationInput!) {
    destroyIntegration(input: $input) {
      id
    }
  }
`

type OpenDeleteAvalaraIntegrationDialogData = {
  provider: DeleteAvalaraIntegrationDialogFragment
  callback?: () => void
}

export const useDeleteAvalaraIntegrationDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const client = useApolloClient()

  const [deleteAvalara] = useDestroyNangoIntegrationMutation()

  const openDeleteAvalaraIntegrationDialog = (data: OpenDeleteAvalaraIntegrationDialogData) => {
    const provider = data.provider

    centralizedDialog.open({
      title: translate('text_658461066530343fe1808cd7', { name: provider?.name }),
      description: translate('text_1744293719130klvtjda8wjz'),
      actionText: translate('text_645d071272418a14c1c76a81'),
      colorVariant: 'danger',
      onAction: async () => {
        const res = await deleteAvalara({
          variables: { input: { id: provider?.id as string } },
        })

        const destroyedId = res.data?.destroyIntegration?.id

        if (destroyedId) {
          evictFromCache(client, {
            id: destroyedId,
            __typename: 'AvalaraIntegration',
            listFieldName: 'integrations',
            listQueryDocument: GetAvalaraIntegrationsListDocument,
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

  return { openDeleteAvalaraIntegrationDialog }
}
