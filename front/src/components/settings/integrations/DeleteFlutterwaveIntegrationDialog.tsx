import { gql, useApolloClient } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { evictFromCache } from '~/core/apolloClient/evictFromCache'
import {
  DeleteFlutterwaveIntegrationDialogFragment,
  GetFlutterwaveIntegrationsListDocument,
  useDeleteFlutterwaveIntegrationMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteFlutterwaveIntegrationDialog on FlutterwaveProvider {
    id
    name
  }
  mutation deleteFlutterwaveIntegration($input: DestroyPaymentProviderInput!) {
    destroyPaymentProvider(input: $input) {
      id
    }
  }
`

type TDeleteFlutterwaveIntegrationDialogProps = {
  provider: DeleteFlutterwaveIntegrationDialogFragment | null
  callback?: () => void
}

export const useDeleteFlutterwaveIntegrationDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const client = useApolloClient()

  const [deleteFlutterwave] = useDeleteFlutterwaveIntegrationMutation()

  const openDeleteFlutterwaveIntegrationDialog = ({
    provider,
    callback,
  }: TDeleteFlutterwaveIntegrationDialogProps) => {
    centralizedDialog.open({
      title: translate('text_1749799070145vfvz9sq757a', { name: provider?.name }),
      description: translate('text_1749799070145zdncdpo3g37'),
      colorVariant: 'danger',
      actionText: translate('text_1749799070145czycjo9guoq'),
      onAction: async () => {
        const result = await deleteFlutterwave({
          variables: { input: { id: provider?.id as string } },
        })

        const destroyedId = result.data?.destroyPaymentProvider?.id

        if (destroyedId) {
          evictFromCache(client, {
            id: destroyedId,
            __typename: 'FlutterwaveProvider',
            listFieldName: 'paymentProviders',
            listQueryDocument: GetFlutterwaveIntegrationsListDocument,
          })

          callback?.()

          addToast({
            message: translate('text_1749799070145axw96s27789'),
            severity: 'success',
          })
        }
      },
    })
  }

  return { openDeleteFlutterwaveIntegrationDialog }
}
