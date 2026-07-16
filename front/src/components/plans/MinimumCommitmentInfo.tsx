import { useMemo } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { getIntervalTranslationKey } from '~/core/constants/form'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum, PlanInterval } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type MinimumCommitmentInfoProps = {
  plan: {
    interval?: PlanInterval | null
    amountCurrency?: CurrencyEnum | null
    minimumCommitment?: {
      amountCents?: number | string | null
      invoiceDisplayName?: string | null
      taxes?: Array<{ name: string; rate: number }> | null
    } | null
  }
  currency: CurrencyEnum
}

export const MinimumCommitmentInfo = ({ plan, currency }: MinimumCommitmentInfoProps) => {
  const { translate } = useInternationalization()

  const body = useMemo(
    () => [
      [
        intlFormatNumber(
          deserializeAmount(
            plan.minimumCommitment?.amountCents || 0,
            plan.amountCurrency || CurrencyEnum.Usd,
          ),
          { currency },
        ),
      ],
    ],
    [plan.minimumCommitment?.amountCents, plan.amountCurrency, currency],
  )

  const grid = useMemo(
    () => [
      {
        label: translate('text_65201b8216455901fe273dc1'),
        value: translate(getIntervalTranslationKey[plan.interval as PlanInterval]),
      },
      {
        label: translate('text_645bb193927b375079d28a8f'),
        value: !!plan.minimumCommitment?.taxes?.length
          ? plan.minimumCommitment.taxes.map((tax, i) => (
              <Typography key={`min-commitment-tax-${i}`} variant="body" color="grey700">
                {tax.name} ({intlFormatNumber(Number(tax.rate) / 100 || 0, { style: 'percent' })})
              </Typography>
            ))
          : '-',
      },
    ],
    [plan.interval, plan.minimumCommitment?.taxes, translate],
  )

  return (
    <div className="flex flex-col gap-4">
      <DetailsPage.TableDisplay
        name="minimum-commitment"
        header={[translate('text_65d601bffb11e0f9d1d9f571')]}
        body={body}
      />

      <DetailsPage.InfoGrid grid={grid} />
    </div>
  )
}
