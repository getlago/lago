import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { SettingsListItem, SettingsListItemHeader } from '~/components/layouts/Settings'
import { getTimezoneConfig } from '~/core/timezone'
import { BillingEntity, TimezoneEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { usePermissions } from '~/hooks/usePermissions'
import { useEditBillingEntityTimezoneDialog } from '~/pages/settings/BillingEntity/sections/general/EditBillingEntityTimezoneDialog'

type TimezoneBlockProps = {
  billingEntity: BillingEntity
}

const TimezoneBlock = ({ billingEntity }: TimezoneBlockProps) => {
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const { isPremium } = useCurrentUser()

  const { id, timezone } = billingEntity
  const timezoneConfig = getTimezoneConfig(timezone)

  const { openEditBillingEntityTimezoneDialog } = useEditBillingEntityTimezoneDialog()
  const premiumWarningDialog = usePremiumWarningDialog()

  return (
    <SettingsListItem>
      <SettingsListItemHeader
        label={translate('text_638906e7b4f1a919cb61d0f4')}
        sublabel={translate('text_17279506108559c3u84iznh2')}
        action={
          <>
            {hasPermissions(['organizationUpdate']) && (
              <Button
                variant="inline"
                endIcon={isPremium ? undefined : 'sparkles'}
                onClick={() => {
                  isPremium
                    ? openEditBillingEntityTimezoneDialog({ id, timezone })
                    : premiumWarningDialog.open()
                }}
              >
                {translate('text_638906e7b4f1a919cb61d0f2')}
              </Button>
            )}
          </>
        }
      />

      <Typography color="grey700">
        {translate('text_638f743fa9a2a9545ee6409a', {
          zone: translate(timezone || TimezoneEnum.TzUtc),
          offset: timezoneConfig.offset,
        })}
      </Typography>
    </SettingsListItem>
  )
}

export default TimezoneBlock
