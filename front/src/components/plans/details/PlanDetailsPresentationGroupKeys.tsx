import { Icon } from 'lago-design-system'

import { Chip } from '~/components/designSystem/Chip'
import { Typography } from '~/components/designSystem/Typography'
import { Properties } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type PlanDetailsPresentationGroupKeysProps = {
  presentationGroupKeys?: Properties['presentationGroupKeys']
}

const PlanDetailsPresentationGroupKeys = ({
  presentationGroupKeys,
}: PlanDetailsPresentationGroupKeysProps) => {
  const { translate } = useInternationalization()

  if (!presentationGroupKeys?.length) {
    return null
  }

  return (
    <div className="flex flex-col">
      <Typography variant="captionHl">{translate('text_17774502138912d3etwcacpe')}</Typography>

      <div className="flex flex-col gap-3">
        {presentationGroupKeys.map((key, index) => {
          const isOnInvoice = key.options?.displayInInvoice === true

          return (
            <div key={index} className="grid grid-cols-[7.5rem_1fr] items-center gap-3">
              <div className="flex flex-row items-center gap-2">
                <Icon
                  name={isOnInvoice ? 'validate-filled' : 'close-circle-filled'}
                  color={isOnInvoice ? 'input' : 'disabled'}
                  size="medium"
                />
                <Typography variant="captionHl" color="grey700">
                  {isOnInvoice
                    ? translate('text_1777456950225zgyccgcm3x4')
                    : translate('text_1777456950225qhho55pdxm8')}
                </Typography>
              </div>
              <Chip label={key.value} size="medium" />
            </div>
          )
        })}
      </div>
    </div>
  )
}

export default PlanDetailsPresentationGroupKeys
