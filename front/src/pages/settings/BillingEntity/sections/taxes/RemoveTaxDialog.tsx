import { gql } from '@apollo/client'

import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { Tax, useRemoveBillingEntityTaxesMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  mutation removeBillingEntityTaxes($input: RemoveTaxesInput!) {
    billingEntityRemoveTaxes(input: $input) {
      __typename
    }
  }
`

type RemoveTaxDialogData = {
  billingEntityId: string
  tax: Tax
}

export const useRemoveTaxDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()

  const [removeTax] = useRemoveBillingEntityTaxesMutation({
    onCompleted(data) {
      if (data) {
        addToast({
          message: translate('text_1743600025133mbqa82o5m39'),
          severity: 'success',
        })
      }
    },
    refetchQueries: ['getBillingEntityTaxes'],
  })

  const openRemoveTaxDialog = ({ billingEntityId, tax }: RemoveTaxDialogData) => {
    centralizedDialog.open({
      title: translate('text_1743241419871l3utqcy1e3h'),
      description: <Typography>{translate('text_1743241419871xs0wuhvffq9')}</Typography>,
      colorVariant: 'danger',
      actionText: translate('text_645bb193927b375079d28b34'),
      onAction: async () => {
        await removeTax({
          variables: {
            input: {
              billingEntityId,
              taxCodes: [tax.code],
            },
          },
        })
      },
    })
  }

  return { openRemoveTaxDialog }
}
