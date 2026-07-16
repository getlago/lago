import { gql, useApolloClient } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { evictFromCache } from '~/core/apolloClient/evictFromCache'
import {
  DeleteNetsuiteIntegrationDialogFragment,
  GetNetsuiteIntegrationsListDocument,
  useDestroyNangoIntegrationMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteNetsuiteIntegrationDialog on NetsuiteIntegration {
    id
    name
  }

  mutation destroyNangoIntegration($input: DestroyIntegrationInput!) {
    destroyIntegration(input: $input) {
      id
    }
  }
`

type TDeleteNetsuiteIntegrationDialogProps = {
  provider: DeleteNetsuiteIntegrationDialogFragment | null
  callback?: () => void
}

export const useDeleteNetsuiteIntegrationDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const client = useApolloClient()

  const [deleteNetsuite] = useDestroyNangoIntegrationMutation()

  const openDeleteNetsuiteIntegrationDialog = ({
    provider,
    callback,
  }: TDeleteNetsuiteIntegrationDialogProps) => {
    centralizedDialog.open({
      title: translate('text_658461066530343fe1808cd7', { name: provider?.name }),
      description: translate('text_661ff6e56ef7e1b7c542b1ec'),
      colorVariant: 'danger',
      actionText: translate('text_645d071272418a14c1c76a81'),
      onAction: async () => {
        const result = await deleteNetsuite({
          variables: { input: { id: provider?.id as string } },
        })

        const destroyedId = result.data?.destroyIntegration?.id

        if (destroyedId) {
          evictFromCache(client, {
            id: destroyedId,
            __typename: 'NetsuiteIntegration',
            listFieldName: 'integrations',
            listQueryDocument: GetNetsuiteIntegrationsListDocument,
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

  return { openDeleteNetsuiteIntegrationDialog }
}
