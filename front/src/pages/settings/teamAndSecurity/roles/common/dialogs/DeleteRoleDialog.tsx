import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { RoleItem } from '~/core/constants/roles'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { useRoleActions } from '../../hooks/useRoleActions'

export const useDeleteRoleDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const { deleteRole } = useRoleActions()

  const openDeleteRoleDialog = (role: RoleItem) => {
    centralizedDialog.open({
      title: translate('text_17677905696331arrjnqzwwb'),
      description: (
        <Typography>
          {translate('text_1767790569633bso609s2bau', {
            roleName: role.name,
          })}
        </Typography>
      ),
      colorVariant: 'danger',
      actionText: translate('text_176779056963310shb5ayw55'),
      onAction: async () => {
        await deleteRole({
          id: role.id,
        })
      },
    })
  }

  return { openDeleteRoleDialog }
}
