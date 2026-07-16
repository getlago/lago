import { gql } from '@apollo/client'

import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import {
  BillingEntity,
  useRemoveBillingEntityInvoiceCustomSectionMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  mutation removeBillingEntityInvoiceCustomSection($input: UpdateBillingEntityInput!) {
    updateBillingEntity(input: $input) {
      id
    }
  }
`

type RemoveInvoiceCustomSectionDialogArgs = {
  billingEntity: BillingEntity
  invoiceCustomSectionId: string
}

export const useRemoveInvoiceCustomSectionDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()

  const [removeInvoiceCustomSection] = useRemoveBillingEntityInvoiceCustomSectionMutation({
    onCompleted(data) {
      if (data) {
        addToast({
          message: translate('text_1749026767605fq828vbnnwr'),
          severity: 'success',
        })
      }
    },
    refetchQueries: ['getBillingEntity'],
  })

  const openRemoveInvoiceCustomSectionDialog = ({
    billingEntity,
    invoiceCustomSectionId,
  }: RemoveInvoiceCustomSectionDialogArgs) => {
    centralizedDialog.open({
      title: translate('text_1749026767605ghziw4tp647'),
      description: <Typography>{translate('text_17490267676056wp5w8xz9h5')}</Typography>,
      colorVariant: 'danger',
      actionText: translate('text_1749035464124mstmqfrzuvl'),
      onAction: async () => {
        await removeInvoiceCustomSection({
          variables: {
            input: {
              id: billingEntity.id,
              invoiceCustomSectionIds: [
                ...(billingEntity?.selectedInvoiceCustomSections
                  ?.filter((s) => s.id !== invoiceCustomSectionId)
                  .map((s) => s.id) || []),
              ],
            },
          },
        })
      },
    })
  }

  return { openRemoveInvoiceCustomSectionDialog }
}
