import Stack from '@mui/material/Stack'
import { Icon } from 'lago-design-system'
import { useMemo } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { BasicComboBoxData } from '~/components/form/ComboBox/types'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withFieldGroup } from '~/hooks/forms/useAppform'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useRoleDisplayInformation } from '~/hooks/useRoleDisplayInformation'
import { useRolesList } from '~/hooks/useRolesList'

import { UpdateInviteSingleRole } from '../common/inviteTypes'

const defaultValues: UpdateInviteSingleRole = {
  role: '',
}

const RolePicker = withFieldGroup({
  defaultValues,
  render: function Render({ group }) {
    const { isPremium, currentMembership } = useCurrentUser()
    const { translate } = useInternationalization()
    const { roles, isLoadingRoles } = useRolesList()
    const { open: openPremiumDialog } = usePremiumWarningDialog()

    const { getDisplayName, getDisplayDescription } = useRoleDisplayInformation()

    const isCurrentUserAdmin = useMemo(() => {
      if (!currentMembership?.roles || !roles.length) return false

      return currentMembership.roles.some((userRole) => {
        const roleObj = roles.find((r) => r.name === userRole)

        return roleObj?.admin
      })
    }, [currentMembership?.roles, roles])

    const rolesDataForCombobox = useMemo<BasicComboBoxData[]>(() => {
      if (isLoadingRoles || !roles.length) {
        return []
      }

      return roles.map((role) => ({
        value: role.code,
        label: getDisplayName(role),
        description: getDisplayDescription(role),
        disabled: (role.admin && !isCurrentUserAdmin) || (!role.admin && !isPremium),
      }))
    }, [
      roles,
      isLoadingRoles,
      getDisplayName,
      getDisplayDescription,
      isPremium,
      isCurrentUserAdmin,
    ])

    return (
      <div className="flex flex-col gap-4">
        <group.AppField name="role">
          {(field) => (
            <field.ComboBoxField
              label={translate('text_664f035a68227f00e261b7ec')}
              data={rolesDataForCombobox}
              placeholder={translate('text_1767193385926vevp8z0azr2')}
              PopperProps={{ displayInDialog: true }}
              sortValues={false}
            />
          )}
        </group.AppField>
        {!isPremium && (
          <div className="flex items-center justify-between gap-4 rounded-xl bg-grey-100 px-6 py-4">
            <Stack>
              <Stack direction="row" gap={2} alignItems="center">
                <Typography variant="bodyHl" color="grey700">
                  {translate('text_665edfd17997c0006f09cdb2')}
                </Typography>
                <Icon name="sparkles" />
              </Stack>
              <Typography variant="caption" color="grey600">
                {translate('text_665edfd17997c0006f09cdb3')}
              </Typography>
            </Stack>
            <Button variant="tertiary" endIcon="sparkles" onClick={() => openPremiumDialog()}>
              {translate('text_65ae73ebe3a66bec2b91d72d')}
            </Button>
          </div>
        )}
      </div>
    )
  },
})

export default RolePicker
