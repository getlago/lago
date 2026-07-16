import { gql } from '@apollo/client/core'
import { useId, useMemo } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum, ThresholdForRecurringThresholdsTableFragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment ThresholdForRecurringThresholdsTable on UsageThreshold {
    id
    amountCents
    thresholdDisplayName
  }
`

export const RecurringThresholdsTable = ({
  thresholds,
  currency,
  name,
}: {
  thresholds: ThresholdForRecurringThresholdsTableFragment[]
  currency: CurrencyEnum
  name?: string
}) => {
  const id = useId()
  const { translate } = useInternationalization()

  const thresholdsForDisplay = useMemo(() => {
    return thresholds.map((threshold) => {
      const displayName = threshold.thresholdDisplayName ? (
        threshold.thresholdDisplayName
      ) : (
        <Typography variant="body" color="grey500">
          {translate('text_177015377629790y0xa6o8g5')}
        </Typography>
      )

      return [
        translate('text_17241798877230y851fdxzqu'),
        intlFormatNumber(deserializeAmount(threshold.amountCents, currency), {
          currency,
        }),
        displayName,
      ]
    })
  }, [thresholds, currency, translate])

  return (
    <DetailsPage.TableDisplay
      name={name || `recurring-thresholds-table-${id.replace(/:/g, '')}`}
      className="[&_tr>td:last-child>div]:inline [&_tr>td:last-child>div]:whitespace-pre [&_tr>td:last-child]:max-w-[100px] [&_tr>td:last-child]:truncate"
      body={[...(thresholdsForDisplay || [])]}
    />
  )
}
