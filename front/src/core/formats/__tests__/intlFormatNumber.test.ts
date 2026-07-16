import {
  bigNumberShortenNotationFormater,
  getCurrencySymbol,
  intlFormatNumber,
  intlFormatOrdinalNumber,
} from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum } from '~/generated/graphql'

const DAYS_ORDINALS_VALUES = [
  '0th',
  '1st',
  '2nd',
  '3rd',
  '4th',
  '5th',
  '6th',
  '7th',
  '8th',
  '9th',
  '10th',
  '11th',
  '12th',
  '13th',
  '14th',
  '15th',
  '16th',
  '17th',
  '18th',
  '19th',
  '20th',
  '21st',
  '22nd',
  '23rd',
  '24th',
  '25th',
  '26th',
  '27th',
  '28th',
  '29th',
  '30th',
  '31st',
]

describe('Currency tools', () => {
  describe('intlFormatNumber()', () => {
    it('should return the amount formatted according to currency', () => {
      const formattedEUR = intlFormatNumber(100050, { currency: CurrencyEnum.Eur })

      // Needs to be done that way as whitespaces breaks the tests
      expect(formattedEUR).toMatch('100,050.00')
      expect(formattedEUR).toMatch('€')

      const formattedUSD = intlFormatNumber(150050, { currency: CurrencyEnum.Usd })

      expect(formattedUSD).toMatch('$')
      expect(formattedUSD).toMatch('150,050.00')

      const formattedJPY = intlFormatNumber(150050, { currency: CurrencyEnum.Jpy })

      expect(formattedJPY).toMatch('¥')
      expect(formattedJPY).toMatch('150,050')
    })

    it('should return the amount formatted according to the unit', () => {
      const formattedEUR = intlFormatNumber(100050, { currency: CurrencyEnum.Eur })

      // Needs to be done that way as whitespaces breaks the tests
      expect(formattedEUR).toMatch('100,050.00')
      expect(formattedEUR).toMatch('€')

      const formattedEURCent = intlFormatNumber(150050, {
        currency: CurrencyEnum.Eur,
      })

      expect(formattedEURCent).toMatch('150,050.00')
      expect(formattedEURCent).toMatch('€')
    })

    it('should return a percentage correctly formated', () => {
      expect(intlFormatNumber(0.1, { style: 'percent' })).toMatch('10.00%')
      expect(intlFormatNumber(0.101, { style: 'percent' })).toMatch('10.10%')
      expect(intlFormatNumber(9.974, { style: 'percent' })).toMatch('997.40%')
      expect(intlFormatNumber(100.1, { style: 'percent' })).toMatch('10,010.00%')
      expect(intlFormatNumber(0.1001, { style: 'percent' })).toMatch('10.01%')
      expect(intlFormatNumber(9.9741, { style: 'percent' })).toMatch('997.41%')
      expect(intlFormatNumber(0.10101, { style: 'percent' })).toMatch('10.101%')
      expect(intlFormatNumber(0.10101, { style: 'percent' })).toMatch('10.101%')
      expect(intlFormatNumber(9.97411, { style: 'percent' })).toMatch('997.411%')
      expect(intlFormatNumber(9.974111, { style: 'percent' })).toMatch('997.4111%')
      expect(intlFormatNumber(1.010101, { style: 'percent' })).toMatch('101.0101%')
      expect(intlFormatNumber(101.0101, { style: 'percent' })).toMatch('10,101.01%')
      expect(intlFormatNumber(1010.101, { style: 'percent' })).toMatch('101,010.10%')
      expect(intlFormatNumber(10101.01, { style: 'percent' })).toMatch('1,010,101.00%')
      expect(intlFormatNumber(101010.1, { style: 'percent' })).toMatch('10,101,010.00%')
      expect(intlFormatNumber(0.1010101, { style: 'percent' })).toMatch('10.101%')
      expect(intlFormatNumber(0.9741111, { style: 'percent' })).toMatch('97.4111%')
    })

    it('should return the amount formatted with pricing unit short name', () => {
      const formattedWithUnit = intlFormatNumber(1500.5, {
        pricingUnitShortName: 'pts',
        currency: CurrencyEnum.Eur,
      })

      expect(formattedWithUnit).toBe('1,500.5 pts')

      const formattedWithUnitInteger = intlFormatNumber(1000, {
        pricingUnitShortName: 'credits',
      })

      expect(formattedWithUnitInteger).toBe('1,000 credits')

      const formattedWithUnitSmallNumber = intlFormatNumber(0.25, {
        pricingUnitShortName: 'units',
      })

      expect(formattedWithUnitSmallNumber).toBe('0.25 units')
    })

    it('should use currency formatting when pricingUnitShortName is provided but style is not currency', () => {
      const formattedPercent = intlFormatNumber(0.1, {
        style: 'percent',
        pricingUnitShortName: 'pts',
      })

      expect(formattedPercent).toMatch('10.00%')
      expect(formattedPercent).not.toMatch('pts')

      const formattedDecimal = intlFormatNumber(1000, {
        style: 'decimal',
        pricingUnitShortName: 'units',
      })

      expect(formattedDecimal).toBe('1,000')
      expect(formattedDecimal).not.toMatch('units')
    })

    it('should respect formatting options when using pricing unit short name', () => {
      const formattedWithOptions = intlFormatNumber(1234.567, {
        pricingUnitShortName: 'tokens',
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      })

      expect(formattedWithOptions).toBe('1,234.57 tokens')

      const formattedWithMinFractionDigits = intlFormatNumber(1000, {
        pricingUnitShortName: 'pts',
        minimumFractionDigits: 3,
      })

      expect(formattedWithMinFractionDigits).toBe('1,000.000 pts')
    })
  })

  describe('getCurrencySymbol', () => {
    it('should return only currency synbol', () => {
      expect(getCurrencySymbol(CurrencyEnum.Usd)).toBe('$')
      expect(getCurrencySymbol(CurrencyEnum.Yer)).toMatch('YER')
      expect(getCurrencySymbol(CurrencyEnum.Gbp)).toBe('£')
      expect(getCurrencySymbol(CurrencyEnum.Eur)).toBe('€')
      expect(getCurrencySymbol(CurrencyEnum.Jpy)).toBe('¥')
    })
  })

  describe('bigNumberShortenNotationFormater()', () => {
    it('should return amount formatted according to currency', () => {
      expect(bigNumberShortenNotationFormater(1)).toBe('$1')
      expect(bigNumberShortenNotationFormater(1, { currency: CurrencyEnum.Eur })).toBe('€1')
      expect(bigNumberShortenNotationFormater(1.1, { currency: CurrencyEnum.Eur })).toBe('€1')
      expect(bigNumberShortenNotationFormater(1.01, { currency: CurrencyEnum.Eur })).toBe('€1')
      expect(bigNumberShortenNotationFormater(10, { currency: CurrencyEnum.Eur })).toBe('€10')
      expect(bigNumberShortenNotationFormater(100, { currency: CurrencyEnum.Eur })).toBe('€100')
      expect(bigNumberShortenNotationFormater(100.01, { currency: CurrencyEnum.Eur })).toBe('€100')
      expect(bigNumberShortenNotationFormater(1_000, { currency: CurrencyEnum.Eur })).toBe('€1k')
      expect(bigNumberShortenNotationFormater(1_000.01, { currency: CurrencyEnum.Eur })).toBe('€1k')
      expect(bigNumberShortenNotationFormater(1_010, { currency: CurrencyEnum.Eur })).toBe('€1k')
      expect(bigNumberShortenNotationFormater(1_100, { currency: CurrencyEnum.Eur })).toBe('€1.1k')
      expect(bigNumberShortenNotationFormater(1_111, { currency: CurrencyEnum.Eur })).toBe('€1.1k')
      expect(bigNumberShortenNotationFormater(10_000, { currency: CurrencyEnum.Eur })).toBe('€10k')
      expect(bigNumberShortenNotationFormater(100_000, { currency: CurrencyEnum.Eur })).toBe(
        '€100k',
      )
      expect(bigNumberShortenNotationFormater(1_000_000, { currency: CurrencyEnum.Eur })).toBe(
        '€1M',
      )
      expect(bigNumberShortenNotationFormater(10_000_000, { currency: CurrencyEnum.Eur })).toBe(
        '€10M',
      )
      expect(bigNumberShortenNotationFormater(100_000_000, { currency: CurrencyEnum.Eur })).toBe(
        '€100M',
      )
      expect(bigNumberShortenNotationFormater(1_000_000_000, { currency: CurrencyEnum.Eur })).toBe(
        '€1B',
      )
      expect(bigNumberShortenNotationFormater(10_000_000_000, { currency: CurrencyEnum.Eur })).toBe(
        '€10B',
      )
      expect(
        bigNumberShortenNotationFormater(100_000_000_000, { currency: CurrencyEnum.Eur }),
      ).toBe('€100B')
      expect(
        bigNumberShortenNotationFormater(1_000_000_000_000, { currency: CurrencyEnum.Eur }),
      ).toBe('€1T')
      expect(
        bigNumberShortenNotationFormater(10_000_000_000_000, { currency: CurrencyEnum.Eur }),
      ).toBe('€10T')
      expect(
        bigNumberShortenNotationFormater(100_000_000_000_000, { currency: CurrencyEnum.Eur }),
      ).toBe('€100T')
      expect(
        bigNumberShortenNotationFormater(1_000_000_000_000_000, { currency: CurrencyEnum.Eur }),
      ).toBe('€1Q')
      expect(
        bigNumberShortenNotationFormater(
          deserializeAmount(100_000_000_000_000_000, CurrencyEnum.Eur),
          { currency: CurrencyEnum.Eur },
        ),
      ).toBe('€1Q')
      expect(
        bigNumberShortenNotationFormater(10_000_000_000_000_000, { currency: CurrencyEnum.Eur }),
      ).toBe('€10Q')
      expect(
        bigNumberShortenNotationFormater(100_000_000_000_000_000, { currency: CurrencyEnum.Eur }),
      ).toBe('€100Q')
      expect(bigNumberShortenNotationFormater(100_000_000_000_000_000)).toBe('$100Q')
    })
  })

  describe('intlFormatOrdinalNumber()', () => {
    it('formats the numbers as ordinal', () => {
      DAYS_ORDINALS_VALUES.forEach((expectedValue, index) => {
        expect(intlFormatOrdinalNumber(index)).toBe(expectedValue)
      })
    })
    it('formats the strings as ordinal', () => {
      DAYS_ORDINALS_VALUES.forEach((expectedValue, index) => {
        expect(intlFormatOrdinalNumber(String(index))).toBe(expectedValue)
      })
    })
  })
})
