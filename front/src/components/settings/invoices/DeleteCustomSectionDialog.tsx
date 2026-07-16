import { gql, useApolloClient } from '@apollo/client'

import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { evictFromCache } from '~/core/apolloClient/evictFromCache'
import {
  DeleteCustomSectionFragment,
  GetOrganizationSettingsInvoiceSectionsDocument,
  useDeleteCustomSectionMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteCustomSection on InvoiceCustomSection {
    id
  }

  mutation deleteCustomSection($input: DestroyInvoiceCustomSectionInput!) {
    destroyInvoiceCustomSection(input: $input) {
      id
    }
  }
`

export const useDeleteCustomSectionDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const client = useApolloClient()

  const [deleteCustomSection] = useDeleteCustomSectionMutation()

  const openDeleteCustomSectionDialog = (customSection: DeleteCustomSectionFragment) => {
    centralizedDialog.open({
      title: translate('text_1732639579760vrvtea9dbua'),
      description: <Typography>{translate('text_1732639579760siwe29e2rqg')}</Typography>,
      colorVariant: 'danger',
      actionText: translate('text_1732639603661uwmv1793v9b'),
      onAction: async () => {
        const result = await deleteCustomSection({
          variables: {
            input: {
              id: customSection?.id || '',
            },
          },
        })

        const destroyedId = result.data?.destroyInvoiceCustomSection?.id

        if (destroyedId) {
          evictFromCache(client, {
            id: destroyedId,
            __typename: 'InvoiceCustomSection',
            listFieldName: 'invoiceCustomSections',
            listQueryDocument: GetOrganizationSettingsInvoiceSectionsDocument,
          })

          addToast({
            message: translate('text_1733849149914twslm71nuy6'),
            severity: 'success',
          })
        }
      },
    })
  }

  return { openDeleteCustomSectionDialog }
}
