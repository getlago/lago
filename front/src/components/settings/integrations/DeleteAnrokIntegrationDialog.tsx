import { gql, useApolloClient } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { evictFromCache } from '~/core/apolloClient/evictFromCache'
import {
  DeleteAnrokIntegrationDialogFragment,
  GetAnrokIntegrationsListDocument,
  useDestroyNangoIntegrationMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteAnrokIntegrationDialog on AnrokIntegration {
    id
    name
  }

  mutation destroyNangoIntegration($input: DestroyIntegrationInput!) {
    destroyIntegration(input: $input) {
      id
    }
  }
`

type TDeleteAnrokIntegrationDialogProps = {
  provider: DeleteAnrokIntegrationDialogFragment | null
  callback?: () => void
}

export const useDeleteAnrokIntegrationDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const client = useApolloClient()

  const [deleteAnrok] = useDestroyNangoIntegrationMutation()

  const openDeleteAnrokIntegrationDialog = ({
    provider,
    callback,
  }: TDeleteAnrokIntegrationDialogProps) => {
    centralizedDialog.open({
      title: translate('text_658461066530343fe1808cd7', { name: provider?.name }),
      description: translate('text_6668870bc8bdb352948ffb5f'),
      colorVariant: 'danger',
      actionText: translate('text_645d071272418a14c1c76a81'),
      onAction: async () => {
        const result = await deleteAnrok({
          variables: { input: { id: provider?.id as string } },
        })

        const destroyedId = result.data?.destroyIntegration?.id

        if (destroyedId) {
          evictFromCache(client, {
            id: destroyedId,
            __typename: 'AnrokIntegration',
            listFieldName: 'integrations',
            listQueryDocument: GetAnrokIntegrationsListDocument,
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

  return { openDeleteAnrokIntegrationDialog }
}
