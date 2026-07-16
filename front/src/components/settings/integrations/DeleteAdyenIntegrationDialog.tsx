import { gql, useApolloClient } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { evictFromCache } from '~/core/apolloClient/evictFromCache'
import {
  DeleteAdyenIntegrationDialogFragment,
  GetAdyenIntegrationsListDocument,
  useDeleteAdyenIntegrationMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteAdyenIntegrationDialog on AdyenProvider {
    id
    name
  }

  mutation deleteAdyenIntegration($input: DestroyPaymentProviderInput!) {
    destroyPaymentProvider(input: $input) {
      id
    }
  }
`

type TDeleteAdyenIntegrationDialogProps = {
  provider: DeleteAdyenIntegrationDialogFragment | null
  callback?: () => void
}

export const useDeleteAdyenIntegrationDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const client = useApolloClient()

  const [deleteAdyen] = useDeleteAdyenIntegrationMutation()

  const openDeleteAdyenIntegrationDialog = ({
    provider,
    callback,
  }: TDeleteAdyenIntegrationDialogProps) => {
    centralizedDialog.open({
      title: translate('text_658461066530343fe1808cd7', { name: provider?.name }),
      description: translate('text_658461066530343fe1808cc2'),
      colorVariant: 'danger',
      actionText: translate('text_645d071272418a14c1c76a81'),
      onAction: async () => {
        const result = await deleteAdyen({
          variables: { input: { id: provider?.id as string } },
        })

        const destroyedId = result.data?.destroyPaymentProvider?.id

        if (destroyedId) {
          evictFromCache(client, {
            id: destroyedId,
            __typename: 'AdyenProvider',
            listFieldName: 'paymentProviders',
            listQueryDocument: GetAdyenIntegrationsListDocument,
          })

          callback?.()

          addToast({
            message: translate('text_645d071272418a14c1c76b25'),
            severity: 'success',
          })
        }
      },
    })
  }

  return { openDeleteAdyenIntegrationDialog }
}
