import { gql } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import {
  AllInvoiceDetailsForCustomerInvoiceDetailsFragmentDoc,
  useDisputeInvoiceMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  mutation disputeInvoice($input: LoseInvoiceDisputeInput!) {
    loseInvoiceDispute(input: $input) {
      id
      status
      ...AllInvoiceDetailsForCustomerInvoiceDetails
    }
  }

  # Fragments needed to refresh data from other parts of the UI
  ${AllInvoiceDetailsForCustomerInvoiceDetailsFragmentDoc}
`

type DisputeInvoiceDialogProps = {
  id: string
}

export const useDisputeInvoiceDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()

  const [disputeInvoice] = useDisputeInvoiceMutation({
    refetchQueries: ['getInvoiceDetails'],
  })

  const openDisputeInvoiceDialog = ({ id }: DisputeInvoiceDialogProps) => {
    centralizedDialog.open({
      title: translate('text_66141e30699a0631f0b2ec59'),
      description: translate('text_66141e30699a0631f0b2ec61'),
      colorVariant: 'danger',
      actionText: translate('text_66141e30699a0631f0b2ec71'),
      onAction: async () => {
        const result = await disputeInvoice({
          variables: { input: { id } },
        })

        if (result.data?.loseInvoiceDispute) {
          addToast({
            message: translate('text_66141e9feef09978ae251222'),
            severity: 'success',
          })
        }
      },
    })
  }

  return { openDisputeInvoiceDialog }
}
