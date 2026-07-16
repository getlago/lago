import { render, screen } from '@testing-library/react'

import { CurrencyEnum } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import {
  CREDIT_ONLY_AMOUNT_LINE_TEST_ID,
  CreditNoteFormCalculation,
} from '../CreditNoteFormCalculation'
import { TaxInfo } from '../useCreditNoteFormCalculation'

const defaultProps = {
  hasError: false,
  currency: CurrencyEnum.Usd,
  estimationLoading: false,
  hasCouponLine: false,
  proRatedCouponAmount: 0,
  totalExcludedTax: 100,
  taxes: new Map<string, TaxInfo>(),
  totalTaxIncluded: 120,
  canOnlyCredit: false,
}

const renderComponent = (props = {}) => {
  return render(<CreditNoteFormCalculation {...defaultProps} {...props} />, {
    wrapper: AllTheProviders,
  })
}

describe('CreditNoteFormCalculation', () => {
  describe('credit only line', () => {
    it('should render credit only line when canOnlyCredit is true', () => {
      renderComponent({ canOnlyCredit: true })

      expect(screen.getByTestId(CREDIT_ONLY_AMOUNT_LINE_TEST_ID)).toBeInTheDocument()
    })

    it('should not render credit only line when canOnlyCredit is false', () => {
      renderComponent({ canOnlyCredit: false })

      expect(screen.queryByTestId(CREDIT_ONLY_AMOUNT_LINE_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('taxes', () => {
    it('should render tax lines when taxes are present', () => {
      const taxes = new Map<string, TaxInfo>([
        ['tax-1', { label: 'VAT', taxRate: 20, amount: 20 }],
        ['tax-2', { label: 'GST', taxRate: 10, amount: 10 }],
      ])

      renderComponent({ taxes, totalExcludedTax: 100 })

      expect(screen.getByTestId('tax-20-amount')).toBeInTheDocument()
      expect(screen.getByTestId('tax-10-amount')).toBeInTheDocument()
    })

    it('should render 0% tax line when no taxes and totalExcludedTax is 0', () => {
      renderComponent({ taxes: new Map(), totalExcludedTax: 0 })

      expect(screen.getByText(/\(0%\)/)).toBeInTheDocument()
    })
  })

  describe('error state', () => {
    it('should show dash values when hasError is true', () => {
      renderComponent({ hasError: true, totalTaxIncluded: 100, totalExcludedTax: 80 })

      const dashValues = screen.getAllByText('-')

      expect(dashValues.length).toBeGreaterThan(0)
    })
  })
})
