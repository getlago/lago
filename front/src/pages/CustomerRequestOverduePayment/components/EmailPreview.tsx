import { FC } from 'react'

import { Avatar } from '~/components/designSystem/Avatar'
import { Card } from '~/components/designSystem/Card'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import {
  DunningEmail,
  DunningEmailProps,
  DunningEmailSkeleton,
} from '~/components/emails/DunningEmail'
import { PremiumIntegrationTypeEnum } from '~/generated/graphql'
import { useContextualLocale } from '~/hooks/core/useContextualLocale'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import Logo from '~/public/images/logo/lago-logo-grey.svg'

interface EmailPreviewProps extends DunningEmailProps {
  isLoading: boolean
}

export const EmailPreview: FC<EmailPreviewProps> = ({
  isLoading,
  locale,
  customer,
  organization,
  overdueAmount,
  currency,
  invoices,
}) => {
  const { translateWithContextualLocal: translate } = useContextualLocale(locale)

  const { hasOrganizationPremiumAddon } = useOrganizationInfos()

  const showPoweredBy = !hasOrganizationPremiumAddon(
    PremiumIntegrationTypeEnum.RemoveBrandingWatermark,
  )

  if (isLoading) {
    return (
      <div className="mx-auto flex max-w-150 flex-col items-center gap-8">
        <div className="flex flex-1 items-center justify-center gap-3">
          <Skeleton variant="connectorAvatar" size="medium" color="dark" />
          <Skeleton variant="text" color="dark" className="w-30" />
        </div>
        <Card className="w-full gap-4">
          <DunningEmailSkeleton />
        </Card>
        <div className="flex justify-center">
          <Skeleton variant="text" color="dark" className="w-30" />
        </div>
      </div>
    )
  }

  return (
    <div className="mx-auto flex max-w-150 flex-col gap-8">
      <div className="flex flex-1 items-center justify-center gap-3">
        {organization?.logoUrl ? (
          <Avatar size="medium" variant="connector">
            <img src={organization?.logoUrl ?? ''} alt={organization?.name} />
          </Avatar>
        ) : (
          <Avatar
            variant="company"
            identifier={organization?.name || ''}
            size="medium"
            initials={(organization?.name ?? '')[0]}
          />
        )}
        <Typography variant="headline" className="font-email" color="textSecondary">
          {organization?.name}
        </Typography>
      </div>
      <Card className="gap-8">
        <DunningEmail
          locale={locale}
          invoices={invoices}
          currency={currency}
          overdueAmount={overdueAmount}
          customer={customer}
          organization={organization}
        />
      </Card>

      {showPoweredBy && (
        <div className="mx-auto flex flex-row items-center gap-1">
          <Typography variant="caption" className="font-email" color="grey500">
            {translate('text_6419c64eace749372fc72b03')}
          </Typography>
          <Logo height="12px" />
        </div>
      )}
    </div>
  )
}
