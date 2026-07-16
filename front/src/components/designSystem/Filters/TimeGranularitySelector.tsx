import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { useNavigate } from '~/core/router'
import { TimeGranularityEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

import { useFilters } from './useFilters'

const GranularityButton = ({
  children,
  isSelected,
  onClick,
}: {
  children: React.ReactNode
  isSelected: boolean
  onClick: () => void
}) => (
  <Button
    size="small"
    className={tw({
      'text-blue-600 [&>div]:text-blue-600': isSelected,
    })}
    variant={isSelected ? 'secondary' : 'quaternary'}
    onClick={onClick}
  >
    {children}
  </Button>
)

const timeGranularityTranslations = {
  [TimeGranularityEnum.Daily]: 'text_1740502406621jc9koixtcyz',
  [TimeGranularityEnum.Weekly]: 'text_1740502406621xxkaea2lnuk',
  [TimeGranularityEnum.Monthly]: 'text_1740502406621t3s23o3x5xj',
}

export const TimeGranularitySelector = () => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { isQuickFilterActive, selectTimeGranularity } = useFilters()

  return (
    <div className="flex items-center gap-1">
      {[TimeGranularityEnum.Daily, TimeGranularityEnum.Weekly, TimeGranularityEnum.Monthly].map(
        (value) => (
          <GranularityButton
            key={`quick-filter-time-interval-${value}`}
            isSelected={isQuickFilterActive({ timeGranularity: value })}
            onClick={() => {
              navigate({ search: selectTimeGranularity(value) })
            }}
          >
            <Typography variant="captionHl" color="grey600">
              {translate(timeGranularityTranslations[value])}
            </Typography>
          </GranularityButton>
        ),
      )}
    </div>
  )
}
