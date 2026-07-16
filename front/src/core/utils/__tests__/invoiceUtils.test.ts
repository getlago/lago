import { CurrencyEnum } from '~/generated/graphql'

import { formatInvoiceDisplayValue } from '../invoiceUtils'

jest.mock('~/core/formats/intlFormatNumber', () => ({
  intlFormatNumber: jest.fn((amount: number, options?: { currency?: string }) => {
    const currencySymbol = options?.currency === 'EUR' ? '€' : '$'

    return `${currencySymbol}${amount.toFixed(2)}`
  }),
}))

describe('invoiceUtils', () => {
  describe('formatInvoiceDisplayValue', () => {
    describe('when hasTaxProvider is true', () => {
      it('should return "-" when taxProviderCondition is false', () => {
        const result = formatInvoiceDisplayValue(true, false, 1000, true, 500, CurrencyEnum.Usd)

        expect(result).toBe('-')
      })

      it('should return formatted taxProviderValue when taxProviderCondition is true and value is defined', () => {
        const result = formatInvoiceDisplayValue(true, true, 1000, true, 500, CurrencyEnum.Usd)

        expect(result).toBe('$1000.00')
      })

      it('should return formatted 0 when taxProviderCondition is true but value is undefined', () => {
        const result = formatInvoiceDisplayValue(true, true, undefined, true, 500, CurrencyEnum.Usd)

        expect(result).toBe('$0.00')
      })

      it('should use the correct currency for tax provider value', () => {
        const result = formatInvoiceDisplayValue(true, true, 1000, true, 500, CurrencyEnum.Eur)

        expect(result).toBe('€1000.00')
      })
    })

    describe('when hasTaxProvider is false', () => {
      it('should return "-" when hasAnyFee is false', () => {
        const result = formatInvoiceDisplayValue(false, false, 1000, false, 500, CurrencyEnum.Usd)

        expect(result).toBe('-')
      })

      it('should return formatted fallbackValue when hasAnyFee is true', () => {
        const result = formatInvoiceDisplayValue(false, false, 1000, true, 500, CurrencyEnum.Usd)

        expect(result).toBe('$500.00')
      })

      it('should use the correct currency for fallback value', () => {
        const result = formatInvoiceDisplayValue(false, false, 1000, true, 750, CurrencyEnum.Eur)

        expect(result).toBe('€750.00')
      })

      it('should ignore taxProviderCondition when hasTaxProvider is false', () => {
        const result = formatInvoiceDisplayValue(false, true, 1000, true, 500, CurrencyEnum.Usd)

        expect(result).toBe('$500.00')
      })

      it('should ignore taxProviderValue when hasTaxProvider is false', () => {
        const result = formatInvoiceDisplayValue(false, false, 9999, true, 500, CurrencyEnum.Usd)

        expect(result).toBe('$500.00')
      })
    })

    describe('edge cases', () => {
      it('should handle zero values correctly', () => {
        const result = formatInvoiceDisplayValue(false, false, 0, true, 0, CurrencyEnum.Usd)

        expect(result).toBe('$0.00')
      })

      it('should handle large values correctly', () => {
        const result = formatInvoiceDisplayValue(false, false, 0, true, 1000000, CurrencyEnum.Usd)

        expect(result).toBe('$1000000.00')
      })

      it('should handle decimal values correctly', () => {
        const result = formatInvoiceDisplayValue(false, false, 0, true, 123.45, CurrencyEnum.Usd)

        expect(result).toBe('$123.45')
      })
    })
  })
})
