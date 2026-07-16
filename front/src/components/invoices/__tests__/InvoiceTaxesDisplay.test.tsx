import { screen } from '@testing-library/react'

import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { INVOICE_TAX_ITEM, INVOICE_TAX_ITEM_NO_TAX } from '../dataTestConstants'
import { InvoiceTaxesDisplay, TaxMapType } from '../InvoiceTaxesDisplay'

jest.mock('~/core/formats/intlFormatNumber', () => ({
  intlFormatNumber: jest.fn((amount: number, options?: { currency?: string }) => {
    const currencySymbol = options?.currency === 'EUR' ? '€' : '$'

    return `${currencySymbol}${amount.toFixed(2)}`
  }),
}))

jest.mock('~/core/serializers/serializeAmount', () => ({
  deserializeAmount: jest.fn((amount: number) => amount),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const invoiceFooterLineClassname = 'flex items-center'

const createTaxMap = (
  taxes: Array<{ id: string; label: string; amount: number; taxRate: number }>,
): TaxMapType => {
  const map = new Map()

  taxes.forEach((tax) => {
    map.set(tax.id, {
      label: tax.label,
      amount: tax.amount,
      taxRate: tax.taxRate,
    })
  })

  return map
}

describe('InvoiceTaxesDisplay', () => {
  describe('when hasTaxProvider is true', () => {
    it('should render empty state when taxProviderTaxesToDisplay is empty', () => {
      render(
        <InvoiceTaxesDisplay
          hasTaxProvider={true}
          taxProviderTaxesToDisplay={new Map()}
          taxesToDisplay={new Map()}
          hasAnyFee={true}
          currency={CurrencyEnum.Usd}
          invoiceFooterLineClassname={invoiceFooterLineClassname}
        />,
      )

      expect(screen.getByText('text_6453819268763979024ad0e9')).toBeInTheDocument()
    })

    it('should render tax items when taxProviderTaxesToDisplay has items', () => {
      const taxProviderTaxesToDisplay = createTaxMap([
        { id: 'tax-1', label: 'VAT (20%)', amount: 2000, taxRate: 20 },
      ])

      render(
        <InvoiceTaxesDisplay
          hasTaxProvider={true}
          taxProviderTaxesToDisplay={taxProviderTaxesToDisplay}
          taxesToDisplay={new Map()}
          hasAnyFee={true}
          currency={CurrencyEnum.Usd}
          invoiceFooterLineClassname={invoiceFooterLineClassname}
        />,
      )

      expect(screen.getByTestId(`${INVOICE_TAX_ITEM}-0`)).toBeInTheDocument()
    })

    it('should render tax items when hasAnyFee is false', () => {
      const taxProviderTaxesToDisplay = createTaxMap([
        { id: 'tax-1', label: 'VAT (20%)', amount: 2000, taxRate: 20 },
      ])

      render(
        <InvoiceTaxesDisplay
          hasTaxProvider={true}
          taxProviderTaxesToDisplay={taxProviderTaxesToDisplay}
          taxesToDisplay={new Map()}
          hasAnyFee={false}
          currency={CurrencyEnum.Usd}
          invoiceFooterLineClassname={invoiceFooterLineClassname}
        />,
      )

      expect(screen.getByTestId(`${INVOICE_TAX_ITEM}-0`)).toBeInTheDocument()
    })
  })

  describe('when hasTaxProvider is false', () => {
    it('should render tax items when taxesToDisplay has items', () => {
      const taxesToDisplay = createTaxMap([
        { id: 'tax-1', label: 'VAT (20%)', amount: 2000, taxRate: 20 },
      ])

      render(
        <InvoiceTaxesDisplay
          hasTaxProvider={false}
          taxProviderTaxesToDisplay={new Map()}
          taxesToDisplay={taxesToDisplay}
          hasAnyFee={true}
          currency={CurrencyEnum.Usd}
          invoiceFooterLineClassname={invoiceFooterLineClassname}
        />,
      )

      expect(screen.getByTestId(`${INVOICE_TAX_ITEM}-0`)).toBeInTheDocument()
    })

    it('should render no-tax state when taxesToDisplay is empty', () => {
      render(
        <InvoiceTaxesDisplay
          hasTaxProvider={false}
          taxProviderTaxesToDisplay={new Map()}
          taxesToDisplay={new Map()}
          hasAnyFee={true}
          currency={CurrencyEnum.Usd}
          invoiceFooterLineClassname={invoiceFooterLineClassname}
        />,
      )

      expect(screen.getByTestId(INVOICE_TAX_ITEM_NO_TAX)).toBeInTheDocument()
    })
  })

  describe('sorting', () => {
    it('should render tax items sorted by taxRate in descending order', () => {
      const taxProviderTaxesToDisplay = createTaxMap([
        { id: 'tax-1', label: 'Low Tax (5%)', amount: 50000, taxRate: 5 },
        { id: 'tax-2', label: 'High Tax (25%)', amount: 250000, taxRate: 25 },
        { id: 'tax-3', label: 'Medium Tax (15%)', amount: 150000, taxRate: 15 },
      ])

      render(
        <InvoiceTaxesDisplay
          hasTaxProvider={true}
          taxProviderTaxesToDisplay={taxProviderTaxesToDisplay}
          taxesToDisplay={new Map()}
          hasAnyFee={true}
          currency={CurrencyEnum.Usd}
          invoiceFooterLineClassname={invoiceFooterLineClassname}
        />,
      )

      expect(screen.getByTestId(`${INVOICE_TAX_ITEM}-0`)).toBeInTheDocument()
      expect(screen.getByTestId(`${INVOICE_TAX_ITEM}-1`)).toBeInTheDocument()
      expect(screen.getByTestId(`${INVOICE_TAX_ITEM}-2`)).toBeInTheDocument()

      const allLabels = screen.getAllByText(/Tax \(\d+%\)/)

      expect(allLabels[0]).toHaveTextContent('High Tax (25%)')
      expect(allLabels[1]).toHaveTextContent('Medium Tax (15%)')
      expect(allLabels[2]).toHaveTextContent('Low Tax (5%)')
    })
  })
})
