import { gql, useApolloClient } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { evictFromCache } from '~/core/apolloClient/evictFromCache'
import {
  DeleteMoneyhashIntegrationDialogFragment,
  GetMoneyhashIntegrationsListDocument,
  useDeleteMoneyhashIntegrationMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteMoneyhashIntegrationDialog on MoneyhashProvider {
    id
    name
  }
  mutation deleteMoneyhashIntegration($input: DestroyPaymentProviderInput!) {
    destroyPaymentProvider(input: $input) {
      id
    }
  }
`

type OpenDeleteMoneyhashIntegrationDialogData = {
  provider: DeleteMoneyhashIntegrationDialogFragment | null
  callback?: () => void
}

export const useDeleteMoneyhashIntegrationDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const client = useApolloClient()

  const [deleteMoneyhash] = useDeleteMoneyhashIntegrationMutation()

  const openDeleteMoneyhashIntegrationDialog = (data: OpenDeleteMoneyhashIntegrationDialogData) => {
    const provider = data.provider

    centralizedDialog.open({
      title: translate('text_658461066530343fe1808cd7', { name: provider?.name }),
      description: translate('text_658461066530343fe1808cc2'),
      actionText: translate('text_645d071272418a14c1c76a81'),
      colorVariant: 'danger',
      onAction: async () => {
        const res = await deleteMoneyhash({
          variables: { input: { id: provider?.id as string } },
        })

        const destroyedId = res.data?.destroyPaymentProvider?.id

        if (destroyedId) {
          evictFromCache(client, {
            id: destroyedId,
            __typename: 'MoneyhashProvider',
            listFieldName: 'paymentProviders',
            listQueryDocument: GetMoneyhashIntegrationsListDocument,
          })

          data.callback?.()

          addToast({
            message: translate('text_1737463302046fgixue5wtvu'),
            severity: 'success',
          })
        }
      },
    })
  }

  return { openDeleteMoneyhashIntegrationDialog }
}
