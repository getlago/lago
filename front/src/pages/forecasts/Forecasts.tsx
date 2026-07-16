import { Icon, tw } from 'lago-design-system'

import { AiBadge } from '~/components/designSystem/AiBadge'
import { Chip } from '~/components/designSystem/Chip'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { FullscreenPage } from '~/components/layouts/FullscreenPage'
import PremiumFeature from '~/components/premium/PremiumFeature'
import { PremiumIntegrationTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { ForecastsOverviewSection } from '~/pages/forecasts/ForecastsOverviewSection'

export const BadgeAI = ({
  badgeClassName,
  iconSize = 12,
  textClassName,
}: {
  badgeClassName?: string
  iconSize?: number
  textClassName?: string
}) => {
  const { translate } = useInternationalization()

  return (
    <div className="flex items-center gap-1">
      <AiBadge className={badgeClassName} iconSize={iconSize}>
        <Typography className={tw('mt-px text-xs font-medium text-purple-700', textClassName)}>
          {translate('text_17530144570404vslv3s1ki3')}
        </Typography>
      </AiBadge>
    </div>
  )
}

const Forecasts = () => {
  const { translate } = useInternationalization()
  const { hasOrganizationPremiumAddon } = useOrganizationInfos()

  const hasAccessToForecastsFeature = hasOrganizationPremiumAddon(
    PremiumIntegrationTypeEnum.ForecastedUsage,
  )

  return (
    <FullscreenPage.Wrapper>
      <div className="flex items-center gap-2">
        <Typography variant="headline" color="grey700">
          {translate('text_1753014457040hxp6wkphkvw')}
        </Typography>

        <Tooltip
          placement="top-start"
          title={translate('text_17530144570400ri03obw5mv')}
          className="flex"
        >
          <Icon name="info-circle" className="text-grey-600" />
        </Tooltip>

        <BadgeAI badgeClassName="px-2 py-1" iconSize={16} textClassName="text-sm" />

        <Chip
          className="bg-purple-100 !px-2 !py-0.5 text-purple-600"
          color="info600"
          size="small"
          label={translate('text_65d8d71a640c5400917f8a13')}
        />
      </div>

      {!hasAccessToForecastsFeature && (
        <div className="max-w-2xl">
          <div>
            <PremiumFeature
              title={translate('text_1761560753771d6ppz3evqxc')}
              description={translate('text_1761560714509hv9325ywuzq')}
              feature={translate('text_1753014457040hxp6wkphkvw')}
            />
          </div>
        </div>
      )}

      {hasAccessToForecastsFeature && <ForecastsOverviewSection />}
    </FullscreenPage.Wrapper>
  )
}

export default Forecasts
