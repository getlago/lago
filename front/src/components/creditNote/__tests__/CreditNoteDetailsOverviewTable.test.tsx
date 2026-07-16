import { render, screen } from '@testing-library/react'

import { CurrencyEnum, FeeTypesEnum, InvoiceTypeEnum } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import {
  CREDIT_NOTE_DETAILS_TABLE_TEST_IDS,
  CreditNoteDetailsOverviewTable,
} from '../CreditNoteDetailsOverviewTable'

const mockFee = {
  id: 'fee-1',
  amountCents: '5000',
  eventsCount: 1,
  units: 1,
  feeType: FeeTypesEnum.Charge,
  itemName: 'Test Item',
  groupedBy: null,
  invoiceName: 'Test Fee',
  appliedTaxes: [],
  trueUpParentFee: null,
  charge: null,
  chargeFilter: null,
  subscription: {
    id: 'sub-1',
    name: 'Test Subscription',
    plan: {
      id: 'plan-1',
      name: 'Test Plan',
      invoiceDisplayName: null,
    },
  },
}

const baseCreditNote = {
  id: 'credit-note-1',
  currency: CurrencyEnum.Usd,
  totalAmountCents: '10000',
  subTotalExcludingTaxesAmountCents: '9000',
  couponsAdjustmentAmountCents: '0',
  creditAmountCents: '0',
  refundAmountCents: '0',
  offsetAmountCents: '0',
  appliedTaxes: [],
  items: [
    {
      amountCents: '5000',
      amountCurrency: CurrencyEnum.Usd,
      fee: mockFee,
    },
  ],
  invoice: {
    id: 'invoice-1',
    invoiceType: InvoiceTypeEnum.Subscription,
    number: 'INV-001',
  },
}

const renderComponent = (props = {}) => {
  return render(
    <CreditNoteDetailsOverviewTable loading={false} creditNote={baseCreditNote} {...props} />,
    { wrapper: AllTheProviders },
  )
}

describe('CreditNoteDetailsOverviewTable', () => {
  describe('GIVEN loading state', () => {
    it('WHEN loading is true THEN should not render footer', () => {
      renderComponent({ loading: true })

      expect(
        screen.queryByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.footer),
      ).not.toBeInTheDocument()
    })

    it('WHEN loading is false THEN should render footer', () => {
      renderComponent({ loading: false })

      expect(screen.getByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.footer)).toBeInTheDocument()
    })
  })

  describe('GIVEN a standard subscription invoice', () => {
    it('THEN should render tax rate column', () => {
      renderComponent()

      expect(
        screen.getByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.taxRateColumn),
      ).toBeInTheDocument()
    })

    it('THEN should render sub total row', () => {
      renderComponent()

      expect(screen.getByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.subTotalRow)).toBeInTheDocument()
    })

    it('WHEN no taxes applied THEN should render zero tax row', () => {
      renderComponent()

      expect(screen.getByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.zeroTaxRow)).toBeInTheDocument()
    })

    it('THEN should always render total row', () => {
      renderComponent()

      expect(screen.getByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.totalRow)).toBeInTheDocument()
    })
  })

  describe('GIVEN a prepaid credits invoice', () => {
    const prepaidCreditNote = {
      ...baseCreditNote,
      invoice: {
        ...baseCreditNote.invoice,
        invoiceType: InvoiceTypeEnum.Credit,
      },
    }

    it('THEN should not render tax rate column', () => {
      renderComponent({ creditNote: prepaidCreditNote })

      expect(
        screen.queryByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.taxRateColumn),
      ).not.toBeInTheDocument()
    })

    it('THEN should not render sub total row', () => {
      renderComponent({ creditNote: prepaidCreditNote })

      expect(
        screen.queryByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.subTotalRow),
      ).not.toBeInTheDocument()
    })

    it('THEN should not render zero tax row', () => {
      renderComponent({ creditNote: prepaidCreditNote })

      expect(
        screen.queryByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.zeroTaxRow),
      ).not.toBeInTheDocument()
    })
  })

  describe('GIVEN applied taxes', () => {
    const creditNoteWithTaxes = {
      ...baseCreditNote,
      appliedTaxes: [
        {
          id: 'tax-1',
          taxName: 'VAT',
          taxRate: 20,
          amountCents: '2000',
          baseAmountCents: '10000',
        },
      ],
    }

    it('THEN should render tax rows instead of zero tax row', () => {
      renderComponent({ creditNote: creditNoteWithTaxes })

      expect(screen.getByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.taxRow)).toBeInTheDocument()
      expect(
        screen.queryByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.zeroTaxRow),
      ).not.toBeInTheDocument()
    })
  })

  describe('GIVEN coupon adjustment', () => {
    const creditNoteWithCoupon = {
      ...baseCreditNote,
      couponsAdjustmentAmountCents: '500',
    }

    it('WHEN amount > 0 THEN should render coupon adjustment row', () => {
      renderComponent({ creditNote: creditNoteWithCoupon })

      expect(
        screen.getByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.couponAdjustmentRow),
      ).toBeInTheDocument()
    })

    it('WHEN amount is 0 THEN should not render coupon adjustment row', () => {
      renderComponent()

      expect(
        screen.queryByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.couponAdjustmentRow),
      ).not.toBeInTheDocument()
    })
  })

  describe('GIVEN credit allocation', () => {
    it('WHEN creditAmountCents > 0 THEN should render credit row', () => {
      renderComponent({ creditNote: { ...baseCreditNote, creditAmountCents: '5000' } })

      expect(screen.getByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.creditRow)).toBeInTheDocument()
    })

    it('WHEN creditAmountCents is 0 THEN should not render credit row', () => {
      renderComponent()

      expect(
        screen.queryByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.creditRow),
      ).not.toBeInTheDocument()
    })
  })

  describe('GIVEN refund allocation', () => {
    it('WHEN refundAmountCents > 0 THEN should render refund row', () => {
      renderComponent({ creditNote: { ...baseCreditNote, refundAmountCents: '3000' } })

      expect(screen.getByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.refundRow)).toBeInTheDocument()
    })

    it('WHEN refundAmountCents is 0 THEN should not render refund row', () => {
      renderComponent()

      expect(
        screen.queryByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.refundRow),
      ).not.toBeInTheDocument()
    })
  })

  describe('GIVEN applied to source invoice allocation', () => {
    it('WHEN amount > 0 THEN should render applied to source invoice row', () => {
      renderComponent({
        creditNote: { ...baseCreditNote, offsetAmountCents: '2000' },
      })

      expect(
        screen.getByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.appliedToSourceInvoiceRow),
      ).toBeInTheDocument()
    })

    it('WHEN amount is 0 THEN should not render applied to source invoice row', () => {
      renderComponent()

      expect(
        screen.queryByTestId(CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.appliedToSourceInvoiceRow),
      ).not.toBeInTheDocument()
    })
  })
})
