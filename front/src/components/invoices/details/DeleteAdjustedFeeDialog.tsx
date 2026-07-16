import { gql } from '@apollo/client'

import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { TExtendedRemainingFee } from '~/core/formats/formatInvoiceItemsMap'
import { useDestroyAdjustedFeeMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment FeeForDeleteAdjustmentFeeDialog on Fee {
    id
    invoiceId
  }

  mutation destroyAdjustedFee($input: DestroyAdjustedFeeInput!) {
    destroyAdjustedFee(input: $input) {
      id
    }
  }
`

interface DeleteAdjustedFeeDialogData {
  fee: TExtendedRemainingFee | undefined
  onDelete?: (id: string) => void
}

export const useDeleteAdjustedFeeDialog = () => {
  const { translate } = useInternationalization()
  const centralizedDialog = useCentralizedDialog()

  const [destroyFee] = useDestroyAdjustedFeeMutation({
    onCompleted({ destroyAdjustedFee }) {
      if (destroyAdjustedFee?.id) {
        addToast({
          message: translate('text_1738084927595tzdnuy6oxyu'),
          severity: 'success',
        })
      }
    },
    refetchQueries: ['getInvoiceDetails', 'getInvoiceFees'],
  })

  const openDeleteAdjustedFeeDialog = (data: DeleteAdjustedFeeDialogData) => {
    centralizedDialog.open({
      title: translate('text_65a6b4e2cb38d9b70ec54035'),
      description: <Typography>{translate('text_65a6b4e2cb38d9b70ec53c55')}</Typography>,
      colorVariant: 'danger',
      actionText: translate('text_65a6b4e2cb38d9b70ec54035'),
      onAction: async () => {
        if (data.onDelete) {
          data.onDelete(data.fee?.id || '')
          return
        }

        await destroyFee({
          variables: {
            input: {
              id: data.fee?.id || '',
            },
          },
        })
      },
    })
  }

  return { openDeleteAdjustedFeeDialog }
}
