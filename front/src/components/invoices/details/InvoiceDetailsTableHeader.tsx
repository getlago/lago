import { memo } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

type InvoiceDetailsTableHeaderProps = {
  canHaveUnitPrice: boolean
  displayName: string
  className?: string
  hideVat?: boolean
}

export const InvoiceDetailsTableHeader = memo(
  ({ canHaveUnitPrice, className, displayName, hideVat }: InvoiceDetailsTableHeaderProps) => {
    const { translate } = useInternationalization()

    return (
      <thead className={tw(className)}>
        <tr>
          <th>
            <Typography variant="captionHl" color="grey600">
              {displayName}
            </Typography>
          </th>
          <th>
            <Typography variant="captionHl" color="grey600">
              {translate('text_65771fa3f4ab9a00720726ce')}
            </Typography>
          </th>
          {canHaveUnitPrice && (
            <th>
              <Typography variant="captionHl" color="grey600">
                {translate('text_6453819268763979024ad089')}
              </Typography>
            </th>
          )}
          {!hideVat && (
            <th>
              <Typography variant="captionHl" color="grey600">
                {translate('text_636bedf292786b19d3398f06')}
              </Typography>
            </th>
          )}
          <th>
            <Typography variant="captionHl" color="grey600">
              {translate('text_634d631acf4dce7b0127a3a6')}
            </Typography>
          </th>
          <th>{/* Action column */}</th>
        </tr>
      </thead>
    )
  },
)

InvoiceDetailsTableHeader.displayName = 'InvoiceDetailsTableHeader'
