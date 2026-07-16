import { gql, useApolloClient } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { evictFromCache } from '~/core/apolloClient/evictFromCache'
import {
  DeleteGocardlessIntegrationDialogFragment,
  GetGocardlessIntegrationsListDocument,
  useDeleteGocardlessMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteGocardlessIntegrationDialog on GocardlessProvider {
    id
    name
  }

  mutation deleteGocardless($input: DestroyPaymentProviderInput!) {
    destroyPaymentProvider(input: $input) {
      id
    }
  }
`

type OpenDeleteGocardlessIntegrationDialogData = {
  provider: DeleteGocardlessIntegrationDialogFragment | null
  callback?: () => void
}

export const useDeleteGocardlessIntegrationDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const client = useApolloClient()

  const [deleteGocardless] = useDeleteGocardlessMutation()

  const openDeleteGocardlessIntegrationDialog = (
    data: OpenDeleteGocardlessIntegrationDialogData,
  ) => {
    const provider = data.provider

    centralizedDialog.open({
      title: translate('text_658461066530343fe1808cd7', { name: provider?.name }),
      description: translate('text_65846181a741a1401ecdddb7'),
      actionText: translate('text_659d5de7c9b7f51394f7f3fd'),
      colorVariant: 'danger',
      onAction: async () => {
        const res = await deleteGocardless({
          variables: { input: { id: provider?.id as string } },
        })

        const destroyedId = res.data?.destroyPaymentProvider?.id

        if (destroyedId) {
          evictFromCache(client, {
            id: destroyedId,
            __typename: 'GocardlessProvider',
            listFieldName: 'paymentProviders',
            listQueryDocument: GetGocardlessIntegrationsListDocument,
          })

          data.callback?.()

          addToast({
            message: translate('text_62b1edddbf5f461ab9712758'),
            severity: 'success',
          })
        }
      },
    })
  }

  return { openDeleteGocardlessIntegrationDialog }
}
