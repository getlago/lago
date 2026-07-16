import { Icon } from 'lago-design-system'

import { Skeleton } from '~/components/designSystem/Skeleton'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { ChartWrapper } from '~/components/layouts/Charts'

type ChartHeaderProps = {
  name: string
  tooltipText?: string
  amount: string
  period?: string
  blur?: boolean
  loading?: boolean
}

const ChartHeader = ({
  name,
  tooltipText,
  amount,
  period,
  loading,
  blur = false,
}: ChartHeaderProps) => {
  return (
    <>
      {!!loading ? (
        <div className="flex h-14 flex-col justify-between pb-2 pt-1">
          <Skeleton variant="text" className="mb-1 w-18" />
          <Skeleton variant="text" className="w-40" />
        </div>
      ) : (
        <ChartWrapper className="flex flex-col items-start justify-between gap-2" blur={blur}>
          <div className="flex w-full items-baseline justify-between gap-2">
            <div className="flex items-center gap-2">
              <Typography variant="captionHl" color="grey600">
                {name}
              </Typography>
              {!!tooltipText && (
                <Tooltip className="flex h-5 items-end" placement="top-start" title={tooltipText}>
                  <Icon name="info-circle" />
                </Tooltip>
              )}
            </div>
            {!!period && (
              <Typography variant="note" color="grey600">
                {period}
              </Typography>
            )}
          </div>

          <Typography variant="subhead1" color="grey700">
            {amount}
          </Typography>
        </ChartWrapper>
      )}
    </>
  )
}

export default ChartHeader
