import { useMemo } from 'react'

import { DetailsPage } from '~/components/layouts/DetailsPage'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type ProgressiveBillingInfoProps = {
  plan: {
    amountCurrency?: CurrencyEnum | null
    usageThresholds?: Array<{
      amountCents?: number | string | null
      recurring: boolean
      thresholdDisplayName?: string | null
    }> | null
  }
  currency: CurrencyEnum
}

export const ProgressiveBillingInfo = ({ plan, currency }: ProgressiveBillingInfoProps) => {
  const { translate } = useInternationalization()
  const hasRecurring = plan.usageThresholds?.some((threshold) => threshold.recurring)

  const body = useMemo(
    () => [
      ...(plan.usageThresholds
        ?.filter((t) => !t.recurring)
        .map((threshold, i) => [
          i === 0
            ? translate('text_1724179887723hi673zmbvdj')
            : translate('text_1724179887723917j8ezkd9v'),
          intlFormatNumber(
            deserializeAmount(threshold.amountCents || 0, plan.amountCurrency || CurrencyEnum.Usd),
            { currency },
          ),
          threshold.thresholdDisplayName || '',
        ]) || []),
    ],
    [plan.usageThresholds, plan.amountCurrency, currency, translate],
  )

  const grid = useMemo(
    () => [
      {
        label: translate('text_17241798877230y851fdxzqt'),
        value: hasRecurring
          ? translate('text_65251f46339c650084ce0d57')
          : translate('text_65251f4cd55aeb004e5aa5ef'),
      },
    ],
    [hasRecurring, translate],
  )

  const recurringBody = useMemo(
    () => [
      ...([plan.usageThresholds?.find((t) => t.recurring)]?.map((threshold) => [
        translate('text_17241798877230y851fdxzqu'),
        intlFormatNumber(
          deserializeAmount(threshold?.amountCents || 0, plan.amountCurrency || CurrencyEnum.Usd),
          { currency },
        ),
        threshold?.thresholdDisplayName || '',
      ]) || []),
    ],
    [plan.usageThresholds, plan.amountCurrency, currency, translate],
  )

  return (
    <div className="flex flex-col gap-4">
      <DetailsPage.TableDisplay
        name="progressive-billing"
        className="[&_tr>td:last-child>div]:inline [&_tr>td:last-child>div]:whitespace-pre [&_tr>td:last-child]:max-w-[100px] [&_tr>td:last-child]:truncate"
        header={[
          '',
          translate('text_1724179887723eh12a0kqbdw'),
          translate('text_17241798877234jhvoho4ci9'),
        ]}
        body={body}
      />

      <DetailsPage.InfoGrid grid={grid} />

      {hasRecurring && (
        <DetailsPage.TableDisplay
          name="progressive-billing-recurring"
          className="[&_tr>td:last-child>div]:inline [&_tr>td:last-child>div]:whitespace-pre [&_tr>td:last-child]:max-w-[100px] [&_tr>td:last-child]:truncate"
          // Only take the first recurring threshold
          body={recurringBody}
        />
      )}
    </div>
  )
}
