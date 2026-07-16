import { gql } from '@apollo/client'

import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import {
  DeleteCustomerDocumentLocaleFragment,
  useDeleteCustomerDocumentLocaleMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteCustomerDocumentLocale on Customer {
    id
    name
    displayName
    externalId
  }

  mutation deleteCustomerDocumentLocale($input: UpdateCustomerInput!) {
    updateCustomer(input: $input) {
      id
      billingConfiguration {
        id
        documentLocale
      }
    }
  }
`

export const useDeleteCustomerDocumentLocaleDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()

  const [deleteCustomerDocumentLocale] = useDeleteCustomerDocumentLocaleMutation({
    onCompleted(data) {
      if (data && data.updateCustomer) {
        addToast({
          message: translate('text_63ea0f84f400488553caa79b'),
          severity: 'success',
        })
      }
    },
  })

  const openDeleteCustomerDocumentLocaleDialog = (
    customer: DeleteCustomerDocumentLocaleFragment,
  ) => {
    centralizedDialog.open({
      title: translate('text_63ea0f84f400488553caa68a'),
      description: (
        <Typography
          html={translate('text_63ea0f84f400488553caa691', {
            customerName: customer.displayName,
          })}
        />
      ),
      colorVariant: 'danger',
      actionText: translate('text_63ea0f84f400488553caa697'),
      onAction: async () => {
        await deleteCustomerDocumentLocale({
          variables: {
            input: {
              id: customer.id,
              billingConfiguration: { documentLocale: null },
              // NOTE: API should not require those fields on customer update
              // To be tackled as improvement
              externalId: customer.externalId,
              name: customer.name || '',
            },
          },
        })
      },
    })
  }

  return { openDeleteCustomerDocumentLocaleDialog }
}
