import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { useInviteActions } from '../hooks/useInviteActions'

type RevokeInviteInfos = {
  id: string
  email: string
  organizationName: string
}

export const useRevokeInviteDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const { revokeInvite } = useInviteActions()

  const openRevokeInviteDialog = (inviteInfos: RevokeInviteInfos) => {
    centralizedDialog.open({
      title: translate('text_63208c701ce25db781407430'),
      description: (
        <Typography>
          {translate('text_63208c701ce25db78140743c', {
            memberEmail: inviteInfos.email,
            organizationName: inviteInfos.organizationName,
          })}
        </Typography>
      ),
      colorVariant: 'danger',
      actionText: translate('text_63208c701ce25db78140745e'),
      onAction: async () => {
        await revokeInvite({
          variables: { input: { id: inviteInfos.id } },
        })
      },
    })
  }

  return { openRevokeInviteDialog }
}
