import { Icon } from 'lago-design-system'
import { FC } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { useInternationalization } from '~/hooks/core/useInternationalization'

export const FreemiumAlert: FC = () => {
  const { translate } = useInternationalization()
  const premiumWarningDialog = usePremiumWarningDialog()

  return (
    <div className="flex items-center gap-4 bg-yellow-100 p-12 shadow-b">
      <div className="flex-1">
        <div className="flex flex-row items-center gap-2">
          <Typography variant="bodyHl" color="textSecondary">
            {translate('text_66b25adfd834ed0104345eb7')}
          </Typography>
          <Icon name="sparkles" />
        </div>
        <Typography variant="caption">{translate('text_66b25adfd834ed0104345eb8')}</Typography>
      </div>
      <Button
        variant="tertiary"
        size="large"
        endIcon="sparkles"
        onClick={() => premiumWarningDialog.open()}
      >
        {translate('text_65ae73ebe3a66bec2b91d72d')}
      </Button>
    </div>
  )
}
