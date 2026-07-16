import { Icon } from 'lago-design-system'
import { FC } from 'react'

import { Skeleton } from '~/components/designSystem/Skeleton'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography, TypographyProps } from '~/components/designSystem/Typography'

interface CreditNoteEstimationLineProps {
  label: string
  labelColor?: TypographyProps['color']
  value: string
  loading?: boolean
  tooltipContent?: string
  'data-test'?: string
}

export const CreditNoteEstimationLine: FC<CreditNoteEstimationLineProps> = ({
  label,
  labelColor = 'grey700',
  value,
  loading,
  tooltipContent,
  'data-test': dataTest,
}) => {
  return (
    <div className="flex items-center justify-between" data-test={dataTest}>
      <div className="flex items-center gap-2">
        <Typography variant="bodyHl" color={labelColor}>
          {label}
        </Typography>
        {tooltipContent && (
          <Tooltip className="flex h-5 items-end" placement="top-start" title={tooltipContent}>
            <Icon name="info-circle" />
          </Tooltip>
        )}
      </div>

      {loading && <Skeleton variant="text" className="w-22" />}

      {!loading && <Typography color="grey700">{value}</Typography>}
    </div>
  )
}
