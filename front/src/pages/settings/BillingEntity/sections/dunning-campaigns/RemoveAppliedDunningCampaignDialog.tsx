import { gql } from '@apollo/client'

import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { BillingEntity, useRemoveBillingEntityDunningCampaignMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  mutation removeBillingEntityDunningCampaign(
    $input: BillingEntityUpdateAppliedDunningCampaignInput!
  ) {
    billingEntityUpdateAppliedDunningCampaign(input: $input) {
      id
    }
  }
`

export const useRemoveAppliedDunningCampaignDialog = () => {
  const { translate } = useInternationalization()
  const centralizedDialog = useCentralizedDialog()

  const [removeBillingEntityDunningCampaign] = useRemoveBillingEntityDunningCampaignMutation({
    refetchQueries: ['getBillingEntity'],
  })

  const openRemoveAppliedDunningCampaignDialog = (billingEntity: BillingEntity) => {
    centralizedDialog.open({
      title: translate('text_1750663218391a7zbhnk61ce'),
      description: <Typography>{translate('text_1750663218391z2s6w2of7xp')}</Typography>,
      colorVariant: 'danger',
      actionText: translate('text_175066321839172gm0lkz8eu'),
      onAction: async () => {
        const result = await removeBillingEntityDunningCampaign({
          variables: {
            input: {
              appliedDunningCampaignId: null,
              billingEntityId: billingEntity.id,
            },
          },
        })

        if (result.data) {
          addToast({
            message: translate('text_1750663218391vbamspkjr5g'),
            severity: 'success',
          })
        }
      },
    })
  }

  return { openRemoveAppliedDunningCampaignDialog }
}
