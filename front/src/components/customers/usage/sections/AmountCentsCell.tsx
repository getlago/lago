import { Typography } from '~/components/designSystem/Typography'
import { getPricingUnitAmountCents } from '~/components/subscriptions/SubscriptionCurrentUsageTable'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { LocaleEnum } from '~/core/translations'
import { CurrencyEnum, ProjectedChargeUsage } from '~/generated/graphql'

type AmountCentsCellProps = {
  row: {
    amountCents?: string | number
    pricingUnitAmountCents?: string | number
    pricingUnitProjectedAmountCents?: string | number
    projectedAmountCents?: string | number
  }
  currency: CurrencyEnum
  locale?: LocaleEnum
  pricingUnitShortName?: string
  showProjected?: boolean
}

export const AmountCentsCell = ({
  row,
  currency,
  locale,
  pricingUnitShortName,
  showProjected,
}: AmountCentsCellProps) => (
  <div className="flex flex-col items-end">
    <Typography variant="bodyHl" color="grey700">
      {intlFormatNumber(
        deserializeAmount(getPricingUnitAmountCents(row, showProjected) || 0, currency) || 0,
        {
          currencyDisplay: locale ? 'narrowSymbol' : 'symbol',
          currency,
          locale,
          pricingUnitShortName,
        },
      )}
    </Typography>

    {!!pricingUnitShortName && (
      <Typography variant="caption" color="grey600">
        {intlFormatNumber(
          deserializeAmount(
            showProjected ? (row as ProjectedChargeUsage).projectedAmountCents : row.amountCents,
            currency,
          ),
          {
            currency,
            locale,
            currencyDisplay: locale ? 'narrowSymbol' : 'symbol',
          },
        )}
      </Typography>
    )}
  </div>
)
