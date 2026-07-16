import { Icon } from 'lago-design-system'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { useNavigate } from '~/core/router'
import { CustomerAccountTypeEnum, PremiumIntegrationTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { tw } from '~/styles/utils'

import { useFilters } from './useFilters'

const QuickFilter = ({
  children,
  isSelected,
  onClick,
}: {
  children: React.ReactNode
  isSelected: boolean
  onClick: () => void
}) => (
  <Button
    className={tw({
      'text-blue-600 [&>div]:text-blue-600': isSelected,
    })}
    variant="tertiary"
    align="left"
    onClick={onClick}
  >
    {children}
  </Button>
)

const quickFilterTranslations = {
  [CustomerAccountTypeEnum.Customer]: 'text_65201c5a175a4b0238abf29a',
  [CustomerAccountTypeEnum.Partner]: 'text_1738322099641hkzihmx9qyw',
}

export const CustomerAccountTypeQuickFilter = () => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { isQuickFilterActive, buildQuickFilterUrlParams, hasAppliedFilters } = useFilters()
  const { organization: { premiumIntegrations } = {} } = useOrganizationInfos()
  const { open: openPremiumWarningDialog } = usePremiumWarningDialog()

  const hasAccessToRevenueShare = !!premiumIntegrations?.includes(
    PremiumIntegrationTypeEnum.RevenueShare,
  )

  return (
    <>
      <QuickFilter
        isSelected={
          !hasAppliedFilters ||
          isQuickFilterActive({ accountType: CustomerAccountTypeEnum.Customer })
        }
        onClick={() =>
          navigate({
            search: buildQuickFilterUrlParams({ accountType: CustomerAccountTypeEnum.Customer }),
          })
        }
      >
        <Typography variant="captionHl" color="grey600">
          {translate(quickFilterTranslations[CustomerAccountTypeEnum.Customer])}
        </Typography>
      </QuickFilter>

      <QuickFilter
        isSelected={isQuickFilterActive({ accountType: CustomerAccountTypeEnum.Partner })}
        onClick={() => {
          if (!hasAccessToRevenueShare) {
            return openPremiumWarningDialog()
          }

          navigate({
            search: buildQuickFilterUrlParams({ accountType: CustomerAccountTypeEnum.Partner }),
          })
        }}
      >
        <Typography variant="captionHl" color="grey600" className="flex items-center gap-2">
          {translate(quickFilterTranslations[CustomerAccountTypeEnum.Partner])}

          {!hasAccessToRevenueShare && <Icon name="sparkles" />}
        </Typography>
      </QuickFilter>
    </>
  )
}
