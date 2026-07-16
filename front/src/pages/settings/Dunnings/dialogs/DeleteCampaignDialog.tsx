import { gql } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { DeleteCampaignFragment, useDeleteDunningCampaignMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteCampaign on DunningCampaign {
    id
    appliedToOrganization
  }

  mutation deleteDunningCampaign($input: DestroyDunningCampaignInput!) {
    destroyDunningCampaign(input: $input) {
      id
    }
  }
`

export const useDeleteCampaignDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()

  const [deleteDunningCampaign] = useDeleteDunningCampaignMutation({
    refetchQueries: ['getDunningCampaigns'],
    onCompleted: ({ destroyDunningCampaign }) => {
      if (!destroyDunningCampaign) {
        return
      }

      addToast({
        severity: 'success',
        message: translate('text_1732187313660ayamm4mu716'),
      })
    },
  })

  const openDeleteCampaignDialog = (campaign: DeleteCampaignFragment) => {
    centralizedDialog.open({
      title: translate('text_17321873136600ctyqurb2n2'),
      description: campaign.appliedToOrganization
        ? translate('text_1732187375488dzhyehimjs3')
        : translate('text_1732187375488g4igt5sf7kg'),
      colorVariant: 'danger',
      actionText: translate('text_1732187313660we30lb9kg57'),
      onAction: async () => {
        await deleteDunningCampaign({
          variables: {
            input: {
              id: campaign.id,
            },
          },
        })
      },
    })
  }

  return { openDeleteCampaignDialog }
}
