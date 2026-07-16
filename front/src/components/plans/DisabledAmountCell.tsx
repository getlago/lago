import { Typography } from '~/components/designSystem/Typography'
import { getCurrencySymbol } from '~/core/formats/intlFormatNumber'
import { CurrencyEnum } from '~/generated/graphql'

export const DisabledAmountCell = ({
  amount,
  currency,
  pricingUnitShortName,
}: {
  amount?: string
  currency: CurrencyEnum
  pricingUnitShortName?: string
}) => (
  <div className="flex max-w-31 items-center gap-2 px-4">
    <Typography color="textSecondary">
      {pricingUnitShortName || getCurrencySymbol(currency)}
    </Typography>
    <Typography color="disabled" noWrap>
      {amount || '0.0'}
    </Typography>
  </div>
)
