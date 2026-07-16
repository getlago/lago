import { gql, useApolloClient } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { evictFromCache } from '~/core/apolloClient/evictFromCache'
import {
  DeleteSalesforceIntegrationDialogFragment,
  GetSalesforceIntegrationsListDocument,
  useDestroyNangoIntegrationMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteSalesforceIntegrationDialog on SalesforceIntegration {
    id
    name
  }

  mutation destroyNangoIntegration($input: DestroyIntegrationInput!) {
    destroyIntegration(input: $input) {
      id
    }
  }
`

type TDeleteSalesforceIntegrationDialogProps = {
  provider: DeleteSalesforceIntegrationDialogFragment | null
  callback?: (arg?: unknown) => void
}

export const useDeleteSalesforceIntegrationDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const client = useApolloClient()

  const [deleteSalesforce] = useDestroyNangoIntegrationMutation()

  const openDeleteSalesforceIntegrationDialog = ({
    provider,
    callback,
  }: TDeleteSalesforceIntegrationDialogProps) => {
    centralizedDialog.open({
      title: translate('text_658461066530343fe1808cd7', {
        name: provider?.name,
      }),
      description: translate('text_1731511951723v0hq5fotjrx'),
      colorVariant: 'danger',
      actionText: translate('text_645d071272418a14c1c76a81'),
      onAction: async () => {
        const result = await deleteSalesforce({
          variables: {
            input: {
              id: provider?.id as string,
            },
          },
        })

        const destroyedId = result.data?.destroyIntegration?.id

        if (destroyedId) {
          evictFromCache(client, {
            id: destroyedId,
            __typename: 'SalesforceIntegration',
            listFieldName: 'integrations',
            listQueryDocument: GetSalesforceIntegrationsListDocument,
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

  return { openDeleteSalesforceIntegrationDialog }
}
