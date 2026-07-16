import { Icon } from 'lago-design-system'
import { FC } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Card } from '~/components/designSystem/Card'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'

interface OverviewCardProps {
  title: string
  tooltipContent?: string
  content: string
  caption: string
  isAccentContent?: boolean
  isLoading?: boolean
  refresh?: () => void
}

export const OverviewCard: FC<OverviewCardProps> = ({
  title,
  tooltipContent,
  content,
  caption,
  isAccentContent,
  isLoading,
  refresh,
}) => {
  const { translate } = useInternationalization()

  return (
    <Card className="flex-1 gap-4 p-6">
      {isLoading ? (
        <div className="h-22">
          <Skeleton className="w-22" variant="text" />
          <div className="flex flex-col gap-4">
            <Skeleton className="w-50" variant="text" />
            <Skeleton className="w-12" variant="text" />
          </div>
        </div>
      ) : (
        <>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Typography variant="captionHl">{title}</Typography>

              {tooltipContent && (
                <Tooltip
                  className="flex h-5 items-end"
                  placement="top-start"
                  title={tooltipContent}
                >
                  <Icon name="info-circle" />
                </Tooltip>
              )}
            </div>

            {refresh && (
              <Tooltip placement="top-end" title={translate('text_1738748043939zqoqzz350yj')}>
                <Button variant="quaternary" size="small" icon="reload" onClick={refresh} />
              </Tooltip>
            )}
          </div>

          <div className="flex flex-col gap-1">
            <Typography variant="subhead1" color={isAccentContent ? 'warning700' : 'grey700'}>
              {content}
            </Typography>
            <Typography variant="caption">{caption}</Typography>
          </div>
        </>
      )}
    </Card>
  )
}
