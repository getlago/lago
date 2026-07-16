import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { useMembershipActions } from '../hooks/useMembershipActions'

type RevokeMembershipInfos = {
  id: string
  email: string
  organizationName: string
  isDeletingLastAdmin: boolean
}

export const useRevokeMembershipDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const { revokeMembership } = useMembershipActions()

  const openRevokeMembershipDialog = (infos: RevokeMembershipInfos) => {
    if (infos.isDeletingLastAdmin) {
      centralizedDialog.open({
        title: translate('text_664f0385f68b4b012708f6cd'),
        description: translate('text_664f0385f68b4b012708f6ce'),
        colorVariant: 'info',
        actionText: translate('text_664f0385f68b4b012708f6cf'),
        onAction: () => {},
      })
    } else {
      centralizedDialog.open({
        title: translate('text_63208bfc99e69a28211ec794'),
        description: (
          <Typography>
            {translate('text_63208bfc99e69a28211ec7a6', {
              memberEmail: infos.email,
              organizationName: infos.organizationName,
            })}
          </Typography>
        ),
        colorVariant: 'danger',
        actionText: translate('text_63208bfc99e69a28211ec7b4'),
        onAction: async () => {
          await revokeMembership({
            variables: { input: { id: infos.id } },
          })
        },
      })
    }
  }

  return { openRevokeMembershipDialog }
}
