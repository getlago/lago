import { Icon, IconName } from 'lago-design-system'

import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'

export const SLASH_COMMAND_BLOCK_VIEW_TEST_ID = 'pricing-block-view'

const SlashCommandBlockWrapper = ({
  typeText,
  displayText,
  handleClick,
  icon,
  captionTextPrefix,
  captionTextSuffix,
}: {
  typeText: string
  displayText: string
  handleClick: () => void
  icon: IconName
  captionTextPrefix?: string
  captionTextSuffix?: string
}) => {
  const { translate } = useInternationalization()

  return (
    <div className="block-type-wrapper">
      <div className="block-type-tag">
        <Typography variant="captionHl" color="grey700">
          {typeText}
        </Typography>
      </div>
      <button
        className="pricing-block pricing-block--clickable"
        onMouseDown={(e) => e.stopPropagation()}
        onClick={handleClick}
        data-test={SLASH_COMMAND_BLOCK_VIEW_TEST_ID}
      >
        <div className="pricing-block-content">
          <div className="icon-wrapper">
            <Icon name={icon} />
          </div>
          <div className="pricing-block-text">
            <Typography variant="bodyHl" color="grey700">
              {displayText}
            </Typography>
            <Typography variant="caption">
              {captionTextPrefix && `${captionTextPrefix} • `}
              {translate('text_1780329442633n0oe3prszsw')}
              {captionTextSuffix && ` ${captionTextSuffix}`}
            </Typography>
          </div>
        </div>
        <div className="click-icon-wrapper">
          <Icon name="chevron-right-filled" />
        </div>
      </button>
    </div>
  )
}

export default SlashCommandBlockWrapper
