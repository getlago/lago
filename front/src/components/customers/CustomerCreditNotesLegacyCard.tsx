import { Icon } from 'lago-design-system'

import { Avatar } from '~/components/designSystem/Avatar'
import { Typography } from '~/components/designSystem/Typography'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum, CustomerCreditNotesBalance } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

export const LEGACY_CARD_CONTAINER = 'credit-notes-legacy-card-container'

type CreditNotesBalanceRow = Pick<
  CustomerCreditNotesBalance,
  'currency' | 'billingEntityId' | 'amountCents' | 'creditsAvailableCount'
>

interface CustomerCreditNotesLegacyCardProps {
  creditNotesBalances?: CreditNotesBalanceRow[]
  userCurrency?: CurrencyEnum
}

/**
 * Legacy single "Total amount available" card.
 *
 * Rendered as fallback when **both** `multi_currency` and `multi_entity_billing`
 * are off, preserving the pre-epic UX byte-identical to today.
 *
 * Scopes the displayed amount + count to the bucket matching the customer's
 * default currency so single-currency orgs see exactly one consistent value
 * (and any leaked multi-currency rows from a temporary flag flip are ignored).
 *
 * @deprecated Delete this component when `multi_entity_billing` reaches GA
 * (ING-75 — flag removal). The breakdown table covers all post-GA cases.
 */
export const CustomerCreditNotesLegacyCard = ({
  creditNotesBalances,
  userCurrency,
}: CustomerCreditNotesLegacyCardProps) => {
  const { translate } = useInternationalization()

  const legacyCurrency = userCurrency ?? CurrencyEnum.Usd
  const legacyBucket = creditNotesBalances?.find((b) => b.currency === legacyCurrency)
  const legacyAmountCents = legacyBucket?.amountCents ?? 0
  const legacyCreditsAvailableCount = legacyBucket?.creditsAvailableCount ?? 0

  return (
    <div
      className="flex h-18 items-center justify-between rounded-xl border border-grey-400 px-4 py-3"
      data-test={LEGACY_CARD_CONTAINER}
    >
      <div className="flex items-center">
        <Avatar className="mr-3" size="big" variant="connector">
          <Icon name="wallet" color="dark" />
        </Avatar>
        <div>
          <Typography variant="bodyHl" color="grey700">
            {translate('text_63725b30957fd5b26b308dd9')}
          </Typography>
          <Typography variant="caption" color="grey600">
            {translate(
              'text_63725b30957fd5b26b308ddb',
              { count: legacyCreditsAvailableCount },
              legacyCreditsAvailableCount,
            )}
          </Typography>
        </div>
      </div>
      <Typography variant="body" color="grey700">
        {intlFormatNumber(deserializeAmount(legacyAmountCents, legacyCurrency) || 0, {
          currencyDisplay: 'symbol',
          currency: legacyCurrency,
        })}
      </Typography>
    </div>
  )
}
