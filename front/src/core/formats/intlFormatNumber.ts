import { LocaleEnum } from '~/core/translations'
import { CurrencyEnum } from '~/generated/graphql'

enum CurrencyDisplay {
  code = 'code',
  symbol = 'symbol',
  narrowSymbol = 'narrowSymbol',
}

enum AmountStyle {
  currency = 'currency',
  percent = 'percent',
  decimal = 'decimal',
}

type FormatterOptions = {
  currency?: CurrencyEnum
  pricingUnitShortName?: string
  currencyDisplay?: keyof typeof CurrencyDisplay
  style?: keyof typeof AmountStyle
  minimumFractionDigits?: number
  maximumFractionDigits?: number
  maximumSignificantDigits?: number
  locale?: LocaleEnum
}

export const intlFormatNumber: (amount: number, options?: FormatterOptions) => string = (
  amount,
  options,
) => {
  const formattedToUnit = amount
  const pricingUnitShortName = options?.pricingUnitShortName
  const locale = options?.locale ?? 'en-US'

  const {
    currencyDisplay = CurrencyDisplay.symbol,
    style = AmountStyle.currency,
    currency = CurrencyEnum.Usd,
    ...otherOptions
  } = options || {}

  // For custom pricing units, we need to format as a decimal number first and append the pricing unit short name
  if (!!pricingUnitShortName && style === AmountStyle.currency) {
    const formattedNumber = Number(formattedToUnit).toLocaleString(locale, {
      style: 'decimal',
      ...otherOptions,
    })

    return `${formattedNumber} ${pricingUnitShortName}`
  }

  // For classic currencies or other styles formatting, we can use the native toLocaleString method
  return Number(formattedToUnit).toLocaleString(locale, {
    style,
    currencyDisplay,
    currency,
    ...(style === AmountStyle.percent
      ? { minimumFractionDigits: 2, maximumFractionDigits: 4 }
      : {}),
    ...otherOptions,
  })
}

export const getCurrencySymbol = (currencyCode: CurrencyEnum) => {
  return (1)
    .toLocaleString('en-US', {
      style: 'currency',
      currency: currencyCode,
      currencyDisplay: 'symbol',
    })
    .replace(/[\d., ]/g, '')
}

// Current limitation: does not add the space between amount and currency symbol if the locale notation has one
export const bigNumberShortenNotationFormater = (
  amount: number,
  options?: Omit<FormatterOptions, 'currencyDisplay'>,
) => {
  const {
    style = AmountStyle.currency,
    currency = CurrencyEnum.Usd,
    ...otherOptions
  } = options || {}

  if (amount < 1e3) {
    return intlFormatNumber(Math.floor(amount), {
      style,
      currency,
      currencyDisplay: CurrencyDisplay.symbol,
      minimumFractionDigits: 0,
      maximumFractionDigits: 1,
      ...otherOptions,
    })
  }

  // Precision is not important anymore
  amount = Number(amount.toFixed(0))

  const bigNumberLookup = [
    { value: 1e15, symbol: 'Q' },
    { value: 1e12, symbol: 'T' },
    { value: 1e9, symbol: 'B' },
    { value: 1e6, symbol: 'M' },
    { value: 1e3, symbol: 'k' },
  ]
  const rx = /\.0+$|(\.[0-9]*[1-9])0+$/
  const item = bigNumberLookup.find(function (localItem) {
    return amount >= localItem.value
  })
  const formatedAmount = item
    ? (amount / item.value).toFixed(1).replace(rx, '$1') + item.symbol
    : '0'

  return `${getCurrencySymbol(currency)}${formatedAmount}`
}

export const bigNumberShortenNotation = (amount: number) => {
  const formatted = bigNumberShortenNotationFormater(amount, {
    currency: CurrencyEnum.Usd,
  })

  return formatted.replace('$', '')
}

export const intlFormatOrdinalNumber = (number: number | string) => {
  const pluralRule = new Intl.PluralRules('en-US', {
    type: 'ordinal',
  })

  const suffixes = new Map([
    ['one', 'st'],
    ['two', 'nd'],
    ['few', 'rd'],
    ['other', 'th'],
  ])

  const rule = pluralRule.select(Number(number))
  const suffix = suffixes.get(rule)

  return `${number}${suffix}`
}
