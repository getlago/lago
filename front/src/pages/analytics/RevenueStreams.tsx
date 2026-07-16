import { Icon } from 'lago-design-system'

import { RevenueStreamsBreakdownSection } from '~/components/analytics/revenueStreams/RevenueStreamsBreakdownSection'
import { RevenueStreamsOverviewSection } from '~/components/analytics/revenueStreams/RevenueStreamsOverviewSection'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { FullscreenPage } from '~/components/layouts/FullscreenPage'
import { useInternationalization } from '~/hooks/core/useInternationalization'

const RevenueStreams = () => {
  const { translate } = useInternationalization()

  return (
    <FullscreenPage.Wrapper>
      <Typography className="flex items-center gap-2" variant="headline" color="grey700">
        {translate('text_1739203651003n5f5qzxnhin')}
        <Tooltip
          placement="top-start"
          title={translate('text_1739204265494pq9zoax7hb0')}
          className="flex" //Note: flex is used to shrink the container so have a better tooltip placement
        >
          <Icon name="info-circle" className="text-grey-600" />
        </Tooltip>
      </Typography>

      <RevenueStreamsOverviewSection />

      <RevenueStreamsBreakdownSection />
    </FullscreenPage.Wrapper>
  )
}

export default RevenueStreams
