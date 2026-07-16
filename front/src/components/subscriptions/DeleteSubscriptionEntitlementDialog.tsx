import { gql } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import {
  RemoveSubscriptionEntitlementInput,
  useRemoveSubscriptionEntitlementMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  mutation removeSubscriptionEntitlement($input: RemoveSubscriptionEntitlementInput!) {
    removeSubscriptionEntitlement(input: $input) {
      featureCode
    }
  }
`

type TDeleteSubscriptionEntitlementDialogProps = RemoveSubscriptionEntitlementInput & {
  featureName: string
}

export const useDeleteSubscriptionEntitlementDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()

  const [removeSubscriptionEntitlement] = useRemoveSubscriptionEntitlementMutation({
    refetchQueries: ['getEntitlementsForSubscriptionDetails'],
  })

  const openDeleteSubscriptionEntitlementDialog = ({
    subscriptionId,
    featureCode,
    featureName,
  }: TDeleteSubscriptionEntitlementDialogProps) => {
    centralizedDialog.open({
      title: translate('text_1755857208789vexq2o6uue8'),
      description: translate('text_17561254890563fn418c1xzd', {
        entitlementName: featureName,
      }),
      colorVariant: 'danger',
      actionText: translate('text_1756125489057n75k4pb2lbu'),
      onAction: async () => {
        const result = await removeSubscriptionEntitlement({
          variables: {
            input: {
              subscriptionId,
              featureCode,
            },
          },
        })

        if (result.data?.removeSubscriptionEntitlement?.featureCode) {
          addToast({
            message: translate('text_175585720878953maf5rsy64'),
            severity: 'success',
          })
        }
      },
    })
  }

  return { openDeleteSubscriptionEntitlementDialog }
}
