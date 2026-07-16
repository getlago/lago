import { Icon } from 'lago-design-system'

import { MrrBreakdownSection } from '~/components/analytics/mrr/MrrBreakdownSection'
import { MrrOverviewSection } from '~/components/analytics/mrr/MrrOverviewSection'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { FullscreenPage } from '~/components/layouts/FullscreenPage'
import { useInternationalization } from '~/hooks/core/useInternationalization'

const Mrr = () => {
  const { translate } = useInternationalization()

  return (
    <FullscreenPage.Wrapper>
      <Typography className="flex items-center gap-2" variant="headline" color="grey700">
        {translate('text_1742467279081qp2hoida9d5')}
        <Tooltip
          placement="top-start"
          title={translate('text_1742467279081fgvkpgka073')}
          className="flex" //Note: flex is used to shrink the container so have a better tooltip placement
        >
          <Icon name="info-circle" className="text-grey-600" />
        </Tooltip>
      </Typography>

      <MrrOverviewSection />

      <MrrBreakdownSection />
    </FullscreenPage.Wrapper>
  )
}

export default Mrr
