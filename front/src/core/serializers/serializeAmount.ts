import { CurrencyEnum } from '~/generated/graphql'

const CURRENCIES_WITH_4_DECIMALS = ['CLF']
const CURRENCIES_WITH_3_DECIMALS = ['BHD', 'IQD', 'JOD', 'KWD', 'LYD', 'OMR', 'TND']
const CURRENCIES_WITH_0_DECIMALS = [
  'DJF',
  'GNF',
  'ISK',
  'JPY',
  'KMF',
  'KRW',
  'PYG',
  'CLP',
  'RWF',
  'UGX',
  'VND',
  'VUV',
  'XAF',
  'XOF',
  'XPF',
]

/**
 * Use it to convert the amount value according to currency to be sent to the API
 */
export const serializeAmount = (value: string | number, currency: CurrencyEnum) => {
  const precision = getCurrencyPrecision(currency)

  if (precision === 0) {
    return Math.round(Number(value))
  } else if (precision === 3) {
    return Number((String(Math.round(Number(value) * 1000)).match(/^-?\d+(?:\.\d{0,3})?/) || [])[0])
  } else if (precision === 4) {
    return Number(
      (String(Math.round(Number(value) * 10000)).match(/^-?\d+(?:\.\d{0,4})?/) || [])[0],
    )
  }

  return Number((String(Math.round(Number(value) * 100)).match(/^-?\d+(?:\.\d{0,2})?/) || [])[0])
}

/**
 * Use it to convert an amount value received from the API to a readable unit according to the currency
 */
export const deserializeAmount = (value: string | number, currency: CurrencyEnum) => {
  const precision = getCurrencyPrecision(currency)

  if (precision === 0) {
    return Math.round(Number(value))
  } else if (precision === 3) {
    return Number((String(Number(value) / 1000).match(/^-?\d+(?:\.\d{0,3})?/) || [])[0])
  } else if (precision === 4) {
    return Number((String(Number(value) / 10000).match(/^-?\d+(?:\.\d{0,4})?/) || [])[0])
  }

  return Number((String(Number(value) / 100).match(/^-?\d+(?:\.\d{0,2})?/) || [])[0])
}

export const getCurrencyPrecision = (currency: CurrencyEnum): number => {
  if (CURRENCIES_WITH_0_DECIMALS.includes(currency)) {
    return 0
  } else if (CURRENCIES_WITH_3_DECIMALS.includes(currency)) {
    return 3
  } else if (CURRENCIES_WITH_4_DECIMALS.includes(currency)) {
    return 4
  }

  return 2
}
