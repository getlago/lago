import { gql, useApolloClient } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { evictFromCache } from '~/core/apolloClient/evictFromCache'
import {
  DeleteStripeIntegrationDialogFragment,
  GetStripeIntegrationsListDocument,
  useDeleteStripeMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteStripeIntegrationDialog on StripeProvider {
    id
    name
  }

  mutation deleteStripe($input: DestroyPaymentProviderInput!) {
    destroyPaymentProvider(input: $input) {
      id
    }
  }
`

type TDeleteStripeIntegrationDialogProps = {
  provider: DeleteStripeIntegrationDialogFragment | null
  callback?: () => void
}

export const useDeleteStripeIntegrationDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const client = useApolloClient()

  const [deleteStripe] = useDeleteStripeMutation()

  const openDeleteStripeIntegrationDialog = ({
    provider,
    callback,
  }: TDeleteStripeIntegrationDialogProps) => {
    centralizedDialog.open({
      title: translate('text_658461066530343fe1808cd7', { name: provider?.name }),
      description: translate('text_658461066530343fe1808cdb'),
      colorVariant: 'danger',
      actionText: translate('text_645d071272418a14c1c76a81'),
      onAction: async () => {
        const result = await deleteStripe({
          variables: { input: { id: provider?.id as string } },
        })

        const destroyedId = result.data?.destroyPaymentProvider?.id

        if (destroyedId) {
          evictFromCache(client, {
            id: destroyedId,
            __typename: 'StripeProvider',
            listFieldName: 'paymentProviders',
            listQueryDocument: GetStripeIntegrationsListDocument,
          })

          callback?.()

          addToast({
            message: translate('text_62b1edddbf5f461ab9712758'),
            severity: 'success',
          })
        }
      },
    })
  }

  return { openDeleteStripeIntegrationDialog }
}
