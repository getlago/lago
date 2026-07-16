import { random } from 'lodash'
import { DateTime } from 'luxon'

import { CurrencyEnum, PrepaidCreditsDataForOverviewSectionFragment } from '~/generated/graphql'

const amountRand = () => {
  let a = random(0, 20000)

  if (Math.random() > 0.5) {
    a = a + random(100, 500)
  }

  if (Math.random() > 0.7) {
    return 0
  }

  return a
}

export const formattedPrepaidCreditsDataLoadingFixture: PrepaidCreditsDataForOverviewSectionFragment[] =
  Array.from(Array(10)).map((_, i) => ({
    startOfPeriodDt: DateTime.now()
      .minus({ month: 12 - i })
      .toISO(),
    endOfPeriodDt: DateTime.now()
      .minus({ month: 11 - i })
      .toISO(),
    amountCurrency: CurrencyEnum.Usd,
    consumedAmount: -amountRand(),
    consumedCreditsQuantity: amountRand(),
    offeredAmount: amountRand(),
    offeredCreditsQuantity: amountRand(),
    purchasedAmount: amountRand(),
    purchasedCreditsQuantity: amountRand(),
    voidedAmount: -amountRand(),
    voidedCreditsQuantity: amountRand(),
  }))
