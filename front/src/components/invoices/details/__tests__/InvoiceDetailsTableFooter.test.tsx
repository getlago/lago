import { screen } from '@testing-library/react'

import {
  CREDIT_ROW_GRANTED_TEST_ID,
  CREDIT_ROW_LEGACY_TEST_ID,
  CREDIT_ROW_PURCHASED_TEST_ID,
  InvoiceDetailsTableFooter,
  REGENERATE_ALERT_TEST_ID,
} from '~/components/invoices/details/InvoiceDetailsTableFooter'
import {
  CurrencyEnum,
  FeeForInvoiceDetailsTableFooterFragment,
  InvoiceForDetailsTableFooterFragment,
  InvoiceStatusTypeEnum,
  InvoiceTypeEnum,
} from '~/generated/graphql'
import { render } from '~/test-utils'

const createMockInvoice = (
  overrides: Partial<InvoiceForDetailsTableFooterFragment> = {},
): InvoiceForDetailsTableFooterFragment => ({
  couponsAmountCents: '0',
  creditNotesAmountCents: '0',
  subTotalExcludingTaxesAmountCents: '10000',
  subTotalIncludingTaxesAmountCents: '11000',
  totalAmountCents: '11000',
  totalDueAmountCents: '11000',
  totalSettledAmountCents: '0',
  currency: CurrencyEnum.Usd,
  invoiceType: InvoiceTypeEnum.Subscription,
  status: InvoiceStatusTypeEnum.Finalized,
  taxStatus: null,
  prepaidCreditAmountCents: '0',
  prepaidGrantedCreditAmountCents: null,
  prepaidPurchasedCreditAmountCents: null,
  progressiveBillingCreditAmountCents: '0',
  versionNumber: 4,
  appliedTaxes: [],
  ...overrides,
})

const renderFooter = (invoice: InvoiceForDetailsTableFooterFragment) => {
  return render(
    <table>
      <InvoiceDetailsTableFooter canHaveUnitPrice={false} invoice={invoice} />
    </table>,
  )
}

describe('InvoiceDetailsTableFooter', () => {
  describe('GIVEN the invoice has prepaid credit rows', () => {
    describe('WHEN both granted and purchased credit amounts are present', () => {
      it('THEN should display both granted and purchased credit rows', () => {
        const invoice = createMockInvoice({
          prepaidGrantedCreditAmountCents: '5000',
          prepaidPurchasedCreditAmountCents: '3000',
        })

        renderFooter(invoice)

        expect(screen.getByTestId(CREDIT_ROW_GRANTED_TEST_ID)).toBeInTheDocument()
        expect(screen.getByTestId(CREDIT_ROW_PURCHASED_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId(CREDIT_ROW_LEGACY_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN only granted credit amount is present', () => {
      it('THEN should display only the granted credit row', () => {
        const invoice = createMockInvoice({
          prepaidGrantedCreditAmountCents: '5000',
          prepaidPurchasedCreditAmountCents: null,
        })

        renderFooter(invoice)

        expect(screen.getByTestId(CREDIT_ROW_GRANTED_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId(CREDIT_ROW_PURCHASED_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(CREDIT_ROW_LEGACY_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN only purchased credit amount is present', () => {
      it('THEN should display only the purchased credit row', () => {
        const invoice = createMockInvoice({
          prepaidPurchasedCreditAmountCents: '3000',
          prepaidGrantedCreditAmountCents: null,
        })

        renderFooter(invoice)

        expect(screen.queryByTestId(CREDIT_ROW_GRANTED_TEST_ID)).not.toBeInTheDocument()
        expect(screen.getByTestId(CREDIT_ROW_PURCHASED_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId(CREDIT_ROW_LEGACY_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN neither granted nor purchased but legacy prepaid credit is present', () => {
      it('THEN should display the legacy prepaid credit row', () => {
        const invoice = createMockInvoice({
          prepaidCreditAmountCents: '8000',
          prepaidGrantedCreditAmountCents: null,
          prepaidPurchasedCreditAmountCents: null,
        })

        renderFooter(invoice)

        expect(screen.queryByTestId(CREDIT_ROW_GRANTED_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(CREDIT_ROW_PURCHASED_TEST_ID)).not.toBeInTheDocument()
        expect(screen.getByTestId(CREDIT_ROW_LEGACY_TEST_ID)).toBeInTheDocument()
      })
    })

    describe('WHEN the invoice is a draft', () => {
      it('THEN should not display any prepaid credit rows', () => {
        const invoice = createMockInvoice({
          status: InvoiceStatusTypeEnum.Draft,
          prepaidCreditAmountCents: '8000',
          prepaidGrantedCreditAmountCents: '5000',
          prepaidPurchasedCreditAmountCents: '3000',
        })

        renderFooter(invoice)

        expect(screen.queryByTestId(CREDIT_ROW_GRANTED_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(CREDIT_ROW_PURCHASED_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(CREDIT_ROW_LEGACY_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN isRegenerateFlow is true', () => {
      it('THEN should not display any prepaid credit rows', () => {
        const invoice = createMockInvoice({
          prepaidCreditAmountCents: '8000',
          prepaidGrantedCreditAmountCents: '5000',
          prepaidPurchasedCreditAmountCents: '3000',
        })

        render(
          <table>
            <InvoiceDetailsTableFooter
              canHaveUnitPrice={false}
              invoice={invoice}
              isRegenerateFlow={true}
            />
          </table>,
        )

        expect(screen.queryByTestId(CREDIT_ROW_GRANTED_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(CREDIT_ROW_PURCHASED_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(CREDIT_ROW_LEGACY_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN no credit amounts exist', () => {
      it('THEN should not display any credit rows', () => {
        const invoice = createMockInvoice({
          prepaidCreditAmountCents: '0',
          prepaidGrantedCreditAmountCents: null,
          prepaidPurchasedCreditAmountCents: null,
        })

        renderFooter(invoice)

        expect(screen.queryByTestId(CREDIT_ROW_GRANTED_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(CREDIT_ROW_PURCHASED_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(CREDIT_ROW_LEGACY_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the invoice has fee-level subtotal computation', () => {
    describe('WHEN invoiceFees are provided with applied taxes', () => {
      it('THEN should compute subtotals from individual fees', () => {
        const invoice = createMockInvoice({
          appliedTaxes: [
            {
              id: 'tax-1',
              amountCents: '2000',
              feesAmountCents: '10000',
              taxableAmountCents: '10000',
              taxRate: 20,
              taxName: 'VAT',
              taxCode: 'vat',
              enumedTaxCode: null,
            },
          ],
        })

        const invoiceFees: FeeForInvoiceDetailsTableFooterFragment[] = [
          { id: 'fee-1', amountCents: '5000' },
          { id: 'fee-2', amountCents: '5000' },
        ]

        render(
          <table>
            <InvoiceDetailsTableFooter
              canHaveUnitPrice={false}
              invoice={invoice}
              invoiceFees={invoiceFees}
            />
          </table>,
        )

        expect(
          screen.getByTestId('invoice-details-table-footer-subtotal-excl-tax-value'),
        ).toBeInTheDocument()
        expect(screen.getByTestId('invoice-details-table-footer-tax-0-label')).toBeInTheDocument()
        expect(screen.getByTestId('invoice-details-table-footer-tax-0-value')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the invoice is rendered in the regenerate flow', () => {
    describe('WHEN isRegenerateFlow is true', () => {
      it('THEN should display the tax recalculation alert', () => {
        const invoice = createMockInvoice()

        render(
          <table>
            <InvoiceDetailsTableFooter
              canHaveUnitPrice={false}
              invoice={invoice}
              isRegenerateFlow={true}
            />
          </table>,
        )

        expect(screen.getByTestId(REGENERATE_ALERT_TEST_ID)).toBeInTheDocument()
      })
    })

    describe('WHEN isRegenerateFlow is not set', () => {
      it('THEN should not display the tax recalculation alert', () => {
        const invoice = createMockInvoice()

        renderFooter(invoice)

        expect(screen.queryByTestId(REGENERATE_ALERT_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN there is a progressive billing credit and fees are recomputed', () => {
      it('THEN the total should subtract the progressive billing credit', () => {
        const invoice = createMockInvoice({
          status: InvoiceStatusTypeEnum.Voided,
          progressiveBillingCreditAmountCents: '50000',
          appliedTaxes: [],
        })

        const invoiceFees: FeeForInvoiceDetailsTableFooterFragment[] = [
          { id: 'fee-1', amountCents: '80000' },
        ]

        render(
          <table>
            <InvoiceDetailsTableFooter
              canHaveUnitPrice={false}
              invoice={invoice}
              invoiceFees={invoiceFees}
              isRegenerateFlow={true}
            />
          </table>,
        )

        // Subtotal incl. tax is $800.00, progressive billing credit is -$500.00,
        // so the total must reflect the deduction: $300.00 (not $800.00).
        expect(screen.getByTestId('invoice-details-table-footer-total-value').textContent).toBe(
          '$300.00',
        )
      })
    })
  })

  describe('GIVEN the invoice has applied taxes', () => {
    describe('WHEN the invoice is finalized with tax entries', () => {
      it('THEN should render tax rows', () => {
        const invoice = createMockInvoice({
          appliedTaxes: [
            {
              id: 'tax-1',
              amountCents: '2000',
              feesAmountCents: '10000',
              taxableAmountCents: '10000',
              taxRate: 20,
              taxName: 'VAT',
              taxCode: 'vat',
              enumedTaxCode: null,
            },
          ],
        })

        renderFooter(invoice)

        expect(screen.getByTestId('invoice-details-table-footer-tax-0-label')).toBeInTheDocument()
        expect(screen.getByTestId('invoice-details-table-footer-tax-0-value')).toBeInTheDocument()
      })
    })
  })
})
