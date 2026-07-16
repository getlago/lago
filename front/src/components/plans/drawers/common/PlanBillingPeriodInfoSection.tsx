import { Chip } from '~/components/designSystem/Chip'
import { Typography } from '~/components/designSystem/Typography'
import { usePlanFormContext } from '~/contexts/PlanFormContext'
import { getIntervalTranslationKey } from '~/core/constants/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'

export const PlanBillingPeriodInfoSection = () => {
  const { interval } = usePlanFormContext()
  const { translate } = useInternationalization()

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-col gap-1">
        <Typography color="grey700" variant="captionHl">
          {translate('text_6661fc17337de3591e29e3d1')}
        </Typography>
        <Typography color="grey600" variant="caption">
          {translate('text_1772030294690kg96fwsazm4')}
        </Typography>
      </div>

      <Chip
        label={translate('text_1772030324507alr5hywedel', {
          interval: translate(getIntervalTranslationKey[interval]),
        })}
      />
    </div>
  )
}
