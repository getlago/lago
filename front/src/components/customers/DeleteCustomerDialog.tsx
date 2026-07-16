import { gql, useApolloClient } from '@apollo/client'

import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { evictFromCache } from '~/core/apolloClient/evictFromCache'
import {
  CustomersDocument,
  DeleteCustomerDialogFragment,
  useDeleteCustomerMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteCustomerDialog on Customer {
    id
    name
    displayName
  }

  mutation deleteCustomer($input: DestroyCustomerInput!) {
    destroyCustomer(input: $input) {
      id
    }
  }
`

type OpenDeleteCustomerDialogData = {
  customer?: DeleteCustomerDialogFragment
  onDeleted?: () => void
}

export const useDeleteCustomerDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const client = useApolloClient()

  const [deleteCustomer] = useDeleteCustomerMutation()

  const openDeleteCustomerDialog = (data: OpenDeleteCustomerDialogData) => {
    const customer = data.customer

    centralizedDialog.open({
      title: translate('text_626162c62f790600f850b6e8', {
        customerFullName: customer?.displayName || translate('text_651a8ab50fd34e005d1c1dc7'),
      }),
      description: <Typography html={translate('text_626162c62f790600f850b6f8')} />,
      actionText: translate('text_626162c62f790600f850b712'),
      colorVariant: 'danger',
      onAction: async () => {
        const res = await deleteCustomer({
          variables: { input: { id: customer?.id ?? '' } },
        })

        const destroyedId = res.data?.destroyCustomer?.id

        if (destroyedId) {
          evictFromCache(client, {
            id: destroyedId,
            __typename: 'Customer',
            listFieldName: 'customers',
            listQueryDocument: CustomersDocument,
          })

          // Clear the root subscriptions field so stale references to the
          // just-deleted customer are dropped from cached subscription lists.
          client.cache.modify({
            fields: {
              subscriptions(_, { DELETE }) {
                return DELETE
              },
            },
          })

          data.onDeleted?.()

          addToast({
            message: translate('text_626162c62f790600f850b814'),
            severity: 'success',
          })
        }
      },
    })
  }

  return { openDeleteCustomerDialog }
}
