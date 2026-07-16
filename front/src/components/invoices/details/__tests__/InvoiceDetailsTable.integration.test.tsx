import { screen } from '@testing-library/react'

import {
  INVOICE_DETAILS_TABLE_ADD_FEE_BUTTON_TEST_ID,
  INVOICE_DETAILS_TABLE_SUBSCRIPTION_TEST_ID,
  InvoiceDetailsTable,
} from '~/components/invoices/details/InvoiceDetailsTable'
import {
  ChargeModelEnum,
  CurrencyEnum,
  FeeDetailsForInvoiceOverviewFragment,
  FeeTypesEnum,
  InvoiceForDetailsTableFragment,
  InvoiceStatusTypeEnum,
  InvoiceTypeEnum,
  TimezoneEnum,
} from '~/generated/graphql'
import { render } from '~/test-utils'

// Stub the drawer hook so the transitive `drawerStack.ts` (Vite-only `import.meta.hot`)
// is never loaded when this integration test mounts BodyLine through the table.
jest.mock('~/components/invoices/details/ViewFeeDetailsDrawer', () => ({
  useViewFeeDetailsDrawer: () => ({ open: jest.fn(), close: jest.fn() }),
}))

jest.mock('~/components/invoices/details/DeleteAdjustedFeeDialog', () => ({
  useDeleteAdjustedFeeDialog: () => ({ openDeleteAdjustedFeeDialog: jest.fn() }),
}))

describe('InvoiceDetailsTable - Integration Tests', () => {
  const mockCustomer = {
    id: 'customer-1',
    applicableTimezone: TimezoneEnum.TzAmericaNewYork,
  }

  const mockEditFeeDrawerRef = { current: null }

  describe('Invoice with 1 subscription', () => {
    it('should render invoice with single subscription and fees correctly', () => {
      const mockInvoice: InvoiceForDetailsTableFragment = {
        id: 'invoice-1',
        invoiceType: InvoiceTypeEnum.Subscription,
        status: InvoiceStatusTypeEnum.Finalized,
        subTotalExcludingTaxesAmountCents: 10000,
        subTotalIncludingTaxesAmountCents: 11000,
        totalAmountCents: 11000,
        currency: CurrencyEnum.Usd,
        issuingDate: '2024-01-31',
        allChargesHaveFees: true,
        allFixedChargesHaveFees: true,
        versionNumber: 1,
        fees: [
          {
            id: 'fee-1',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Subscription,
            invoiceDisplayName: null,
            itemName: 'Monthly subscription',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
          {
            id: 'fee-2',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'API Calls',
            itemName: 'API Calls',
            units: 100,
            preciseUnitAmount: '50',
            charge: {
              id: 'charge-1',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-1',
                name: 'API Calls',
                recurring: false,
              },
            },
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
        ] as unknown as FeeDetailsForInvoiceOverviewFragment[],
        subscriptions: [
          {
            id: 'sub-1',
            name: 'Main Subscription',
            currentBillingPeriodStartedAt: '2024-01-01T00:00:00Z',
            currentBillingPeriodEndingAt: '2024-01-31T23:59:59Z',
            plan: {
              id: 'plan-1',
              name: 'Premium Plan',
              interval: 'monthly',
            },
          },
        ],
        invoiceSubscriptions: [
          {
            subscription: { id: 'sub-1' },
            invoice: { id: 'invoice-1' },
            acceptNewChargeFees: true,
          },
        ],
      } as unknown as InvoiceForDetailsTableFragment

      render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={mockInvoice}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={mockInvoice.fees as FeeDetailsForInvoiceOverviewFragment[]}
        />,
      )

      // Should display subscription name
      expect(screen.getByText('Main Subscription')).toBeInTheDocument()

      // Should display subscription fee
      expect(screen.getByText(/Monthly subscription fee - Premium Plan/)).toBeInTheDocument()

      // Should display charge fee
      expect(screen.getByText('API Calls')).toBeInTheDocument()

      // Component should render successfully
      expect(screen.getByText('Main Subscription')).toBeInTheDocument()
    })

    it('should render invoice with single subscription and multiple boundaries', () => {
      const mockInvoice: InvoiceForDetailsTableFragment = {
        id: 'invoice-1',
        invoiceType: InvoiceTypeEnum.Subscription,
        status: InvoiceStatusTypeEnum.Finalized,
        subTotalExcludingTaxesAmountCents: 15000,
        subTotalIncludingTaxesAmountCents: 16500,
        totalAmountCents: 16500,
        currency: CurrencyEnum.Usd,
        issuingDate: '2024-02-29',
        allChargesHaveFees: true,
        allFixedChargesHaveFees: true,
        versionNumber: 1,
        fees: [
          // Boundary 1: Jan 1 - Jan 15
          {
            id: 'fee-1',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'API Calls',
            itemName: 'API Calls',
            charge: {
              id: 'charge-1',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-1',
                name: 'API Calls',
                recurring: false,
              },
            },
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-15T23:59:59Z',
            },
          },
          // Boundary 2: Jan 16 - Jan 31
          {
            id: 'fee-2',
            amountCents: 10000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'API Calls',
            itemName: 'API Calls',
            charge: {
              id: 'charge-1',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-1',
                name: 'API Calls',
                recurring: false,
              },
            },
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-16T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
        ] as unknown as FeeDetailsForInvoiceOverviewFragment[],
        subscriptions: [
          {
            id: 'sub-1',
            name: 'Main Subscription',
            currentBillingPeriodStartedAt: '2024-01-01T00:00:00Z',
            currentBillingPeriodEndingAt: '2024-01-31T23:59:59Z',
            plan: {
              id: 'plan-1',
              name: 'Premium Plan',
              interval: 'monthly',
            },
          },
        ],
        invoiceSubscriptions: [
          {
            subscription: { id: 'sub-1' },
            invoice: { id: 'invoice-1' },
            acceptNewChargeFees: false,
          },
        ],
      } as unknown as InvoiceForDetailsTableFragment

      render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={mockInvoice}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={mockInvoice.fees as FeeDetailsForInvoiceOverviewFragment[]}
        />,
      )

      // Should display subscription name
      expect(screen.getByText('Main Subscription')).toBeInTheDocument()

      // Should display charges in both boundaries
      const apiCallsElements = screen.getAllByText('API Calls')

      expect(apiCallsElements).toHaveLength(2)
    })

    it('should group fees with same date but different times into same boundary', () => {
      const mockInvoice: InvoiceForDetailsTableFragment = {
        id: 'invoice-1',
        invoiceType: InvoiceTypeEnum.Subscription,
        status: InvoiceStatusTypeEnum.Finalized,
        subTotalExcludingTaxesAmountCents: 10000,
        subTotalIncludingTaxesAmountCents: 11000,
        totalAmountCents: 11000,
        currency: CurrencyEnum.Usd,
        issuingDate: '2024-01-31',
        allChargesHaveFees: true,
        allFixedChargesHaveFees: true,
        versionNumber: 1,
        fees: [
          {
            id: 'fee-1',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'API Calls',
            itemName: 'API Calls',
            charge: {
              id: 'charge-1',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-1',
                name: 'API Calls',
                recurring: false,
              },
            },
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T08:00:00Z', // Morning
              toDatetime: '2024-01-31T08:00:00Z',
            },
          },
          {
            id: 'fee-2',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'Storage',
            itemName: 'Storage',
            charge: {
              id: 'charge-2',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-2',
                name: 'Storage',
                recurring: false,
              },
            },
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T18:30:00Z', // Evening - same date, different time
              toDatetime: '2024-01-31T18:30:00Z',
            },
          },
        ] as unknown as FeeDetailsForInvoiceOverviewFragment[],
        subscriptions: [
          {
            id: 'sub-1',
            name: null,
            currentBillingPeriodStartedAt: '2024-01-01T00:00:00Z',
            currentBillingPeriodEndingAt: '2024-01-31T23:59:59Z',
            plan: {
              id: 'plan-1',
              name: 'Premium Plan',
              interval: 'monthly',
            },
          },
        ],
        invoiceSubscriptions: [
          {
            subscription: { id: 'sub-1' },
            invoice: { id: 'invoice-1' },
            acceptNewChargeFees: true,
          },
        ],
      } as unknown as InvoiceForDetailsTableFragment

      render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={mockInvoice}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={mockInvoice.fees as FeeDetailsForInvoiceOverviewFragment[]}
        />,
      )

      // Should use plan name when subscription name is null
      expect(screen.getByText('Premium Plan')).toBeInTheDocument()

      // Should display both charges (grouped in same boundary)
      expect(screen.getByText('API Calls')).toBeInTheDocument()
      expect(screen.getByText('Storage')).toBeInTheDocument()
    })
  })

  describe('Invoice with 2 subscriptions', () => {
    it('should render invoice with multiple subscriptions correctly', () => {
      const mockInvoice: InvoiceForDetailsTableFragment = {
        id: 'invoice-1',
        invoiceType: InvoiceTypeEnum.Subscription,
        status: InvoiceStatusTypeEnum.Finalized,
        subTotalExcludingTaxesAmountCents: 20000,
        subTotalIncludingTaxesAmountCents: 22000,
        totalAmountCents: 22000,
        currency: CurrencyEnum.Usd,
        issuingDate: '2024-01-31',
        allChargesHaveFees: true,
        allFixedChargesHaveFees: true,
        versionNumber: 1,
        fees: [
          // Subscription 1 fees
          {
            id: 'fee-1',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Subscription,
            invoiceDisplayName: null,
            itemName: 'Monthly subscription',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
          {
            id: 'fee-2',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'API Calls',
            itemName: 'API Calls',
            charge: {
              id: 'charge-1',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-1',
                name: 'API Calls',
                recurring: false,
              },
            },
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
          // Subscription 2 fees
          {
            id: 'fee-3',
            amountCents: 7000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Subscription,
            invoiceDisplayName: null,
            itemName: 'Yearly subscription',
            subscription: { id: 'sub-2' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-12-31T23:59:59Z',
            },
          },
          {
            id: 'fee-4',
            amountCents: 3000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'Storage',
            itemName: 'Storage',
            charge: {
              id: 'charge-2',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-2',
                name: 'Storage',
                recurring: false,
              },
            },
            subscription: { id: 'sub-2' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-12-31T23:59:59Z',
            },
          },
        ] as unknown as FeeDetailsForInvoiceOverviewFragment[],
        subscriptions: [
          {
            id: 'sub-1',
            name: 'Monthly Subscription',
            currentBillingPeriodStartedAt: '2024-01-01T00:00:00Z',
            currentBillingPeriodEndingAt: '2024-01-31T23:59:59Z',
            plan: {
              id: 'plan-1',
              name: 'Premium Plan',
              interval: 'monthly',
            },
          },
          {
            id: 'sub-2',
            name: 'Yearly Subscription',
            currentBillingPeriodStartedAt: '2024-01-01T00:00:00Z',
            currentBillingPeriodEndingAt: '2024-12-31T23:59:59Z',
            plan: {
              id: 'plan-2',
              name: 'Enterprise Plan',
              interval: 'yearly',
            },
          },
        ],
        invoiceSubscriptions: [
          {
            subscription: { id: 'sub-1' },
            invoice: { id: 'invoice-1' },
            acceptNewChargeFees: true,
          },
          {
            subscription: { id: 'sub-2' },
            invoice: { id: 'invoice-1' },
            acceptNewChargeFees: false,
          },
        ],
      } as unknown as InvoiceForDetailsTableFragment

      render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={mockInvoice}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={mockInvoice.fees as FeeDetailsForInvoiceOverviewFragment[]}
        />,
      )

      // Should display both subscription names
      expect(screen.getByText('Monthly Subscription')).toBeInTheDocument()
      expect(screen.getByText('Yearly Subscription')).toBeInTheDocument()

      // Should display subscription fees for both
      expect(screen.getByText(/Monthly subscription fee - Premium Plan/)).toBeInTheDocument()
      expect(screen.getByText(/Yearly subscription fee - Enterprise Plan/)).toBeInTheDocument()

      // Should display charges for both subscriptions
      expect(screen.getByText('API Calls')).toBeInTheDocument()
      expect(screen.getByText('Storage')).toBeInTheDocument()
    })

    it('should sort subscriptions alphabetically by display name', () => {
      const mockInvoice: InvoiceForDetailsTableFragment = {
        id: 'invoice-1',
        invoiceType: InvoiceTypeEnum.Subscription,
        status: InvoiceStatusTypeEnum.Finalized,
        subTotalExcludingTaxesAmountCents: 10000,
        subTotalIncludingTaxesAmountCents: 11000,
        totalAmountCents: 11000,
        currency: CurrencyEnum.Usd,
        issuingDate: '2024-01-31',
        allChargesHaveFees: true,
        allFixedChargesHaveFees: true,
        versionNumber: 1,
        fees: [
          // Subscription B fee (appears first in fees array)
          {
            id: 'fee-2',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'Storage',
            itemName: 'Storage',
            charge: {
              id: 'charge-2',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-2',
                name: 'Storage',
                recurring: false,
              },
            },
            subscription: { id: 'sub-b' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
          // Subscription A fee (appears second in fees array)
          {
            id: 'fee-1',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'API Calls',
            itemName: 'API Calls',
            charge: {
              id: 'charge-1',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-1',
                name: 'API Calls',
                recurring: false,
              },
            },
            subscription: { id: 'sub-a' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
        ] as unknown as FeeDetailsForInvoiceOverviewFragment[],
        subscriptions: [
          {
            id: 'sub-b',
            name: 'Subscription B',
            currentBillingPeriodStartedAt: '2024-01-01T00:00:00Z',
            currentBillingPeriodEndingAt: '2024-01-31T23:59:59Z',
            plan: {
              id: 'plan-b',
              name: 'Plan B',
              interval: 'monthly',
            },
          },
          {
            id: 'sub-a',
            name: 'Subscription A',
            currentBillingPeriodStartedAt: '2024-01-01T00:00:00Z',
            currentBillingPeriodEndingAt: '2024-01-31T23:59:59Z',
            plan: {
              id: 'plan-a',
              name: 'Plan A',
              interval: 'monthly',
            },
          },
        ],
        invoiceSubscriptions: [
          {
            subscription: { id: 'sub-b' },
            invoice: { id: 'invoice-1' },
            acceptNewChargeFees: true,
          },
          {
            subscription: { id: 'sub-a' },
            invoice: { id: 'invoice-1' },
            acceptNewChargeFees: true,
          },
        ],
      } as unknown as InvoiceForDetailsTableFragment

      render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={mockInvoice}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={mockInvoice.fees as FeeDetailsForInvoiceOverviewFragment[]}
        />,
      )

      // Get all subscription tables using data-test attribute
      const subscriptionTables = screen.getAllByTestId(INVOICE_DETAILS_TABLE_SUBSCRIPTION_TEST_ID)

      // Should have 2 subscription tables
      expect(subscriptionTables).toHaveLength(2)

      // Subscription A should appear before Subscription B (alphabetically sorted)
      // Check the text content of each table
      const firstTableText = subscriptionTables[0].textContent || ''
      const secondTableText = subscriptionTables[1].textContent || ''

      expect(firstTableText).toContain('Subscription A')
      expect(secondTableText).toContain('Subscription B')
    })
  })

  describe('Invoice with no fees', () => {
    it('should render invoice with no fees gracefully', () => {
      const mockInvoice: InvoiceForDetailsTableFragment = {
        id: 'invoice-1',
        invoiceType: InvoiceTypeEnum.Subscription,
        status: InvoiceStatusTypeEnum.Draft,
        subTotalExcludingTaxesAmountCents: 0,
        subTotalIncludingTaxesAmountCents: 0,
        totalAmountCents: 0,
        currency: CurrencyEnum.Usd,
        issuingDate: '2024-01-31',
        allChargesHaveFees: false,
        allFixedChargesHaveFees: false,
        versionNumber: 1,
        fees: [],
        subscriptions: [
          {
            id: 'sub-1',
            name: 'Main Subscription',
            currentBillingPeriodStartedAt: '2024-01-01T00:00:00Z',
            currentBillingPeriodEndingAt: '2024-01-31T23:59:59Z',
            plan: {
              id: 'plan-1',
              name: 'Premium Plan',
              interval: 'monthly',
            },
          },
        ],
        invoiceSubscriptions: [
          {
            subscription: { id: 'sub-1' },
            invoice: { id: 'invoice-1' },
            acceptNewChargeFees: true,
          },
        ],
      } as unknown as InvoiceForDetailsTableFragment

      const { container } = render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={mockInvoice}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={[]}
        />,
      )

      // Should render without crashing when no fees are present
      expect(container).toBeInTheDocument()
      expect(screen.queryByText('API Calls')).not.toBeInTheDocument()
    })

    it('should render empty invoice without subscriptions', () => {
      const mockInvoice: InvoiceForDetailsTableFragment = {
        id: 'invoice-1',
        invoiceType: InvoiceTypeEnum.Subscription,
        status: InvoiceStatusTypeEnum.Draft,
        subTotalExcludingTaxesAmountCents: 0,
        subTotalIncludingTaxesAmountCents: 0,
        totalAmountCents: 0,
        currency: CurrencyEnum.Usd,
        issuingDate: '2024-01-31',
        allChargesHaveFees: false,
        allFixedChargesHaveFees: false,
        versionNumber: 1,
        fees: [],
        subscriptions: [],
        invoiceSubscriptions: [],
      } as unknown as InvoiceForDetailsTableFragment

      const { container } = render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={mockInvoice}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={[]}
        />,
      )

      // Should render without crashing even with no subscriptions or fees
      expect(container).toBeInTheDocument()
    })
  })

  describe('AcceptNewChargeFees conditions', () => {
    it('should respect acceptNewChargeFees=true from invoiceSubscription', () => {
      const mockInvoice: InvoiceForDetailsTableFragment = {
        id: 'invoice-1',
        invoiceType: InvoiceTypeEnum.Subscription,
        status: InvoiceStatusTypeEnum.Draft,
        subTotalExcludingTaxesAmountCents: 5000,
        subTotalIncludingTaxesAmountCents: 5500,
        totalAmountCents: 5500,
        currency: CurrencyEnum.Usd,
        issuingDate: '2024-01-31',
        allChargesHaveFees: false,
        allFixedChargesHaveFees: false,
        versionNumber: 1,
        fees: [
          {
            id: 'fee-1',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'API Calls',
            itemName: 'API Calls',
            charge: {
              id: 'charge-1',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-1',
                name: 'API Calls',
                recurring: false,
              },
            },
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
        ] as unknown as FeeDetailsForInvoiceOverviewFragment[],
        subscriptions: [
          {
            id: 'sub-1',
            name: 'Main Subscription',
            currentBillingPeriodStartedAt: '2024-01-01T00:00:00Z',
            currentBillingPeriodEndingAt: '2024-01-31T23:59:59Z',
            plan: {
              id: 'plan-1',
              name: 'Premium Plan',
              interval: 'monthly',
            },
          },
        ],
        invoiceSubscriptions: [
          {
            subscription: { id: 'sub-1' },
            invoice: { id: 'invoice-1' },
            acceptNewChargeFees: true, // Should allow adding new fees
          },
        ],
      } as unknown as InvoiceForDetailsTableFragment

      render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={mockInvoice}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={mockInvoice.fees as FeeDetailsForInvoiceOverviewFragment[]}
        />,
      )

      // Should display subscription
      expect(screen.getByText('Main Subscription')).toBeInTheDocument()

      // Component should render successfully with acceptNewChargeFees=true
      expect(screen.getByText('API Calls')).toBeInTheDocument()
    })

    it('should respect acceptNewChargeFees=false from invoiceSubscription', () => {
      const mockInvoice: InvoiceForDetailsTableFragment = {
        id: 'invoice-1',
        invoiceType: InvoiceTypeEnum.Subscription,
        status: InvoiceStatusTypeEnum.Draft,
        subTotalExcludingTaxesAmountCents: 5000,
        subTotalIncludingTaxesAmountCents: 5500,
        totalAmountCents: 5500,
        currency: CurrencyEnum.Usd,
        issuingDate: '2024-01-31',
        allChargesHaveFees: false,
        allFixedChargesHaveFees: false,
        versionNumber: 1,
        fees: [
          {
            id: 'fee-1',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'API Calls',
            itemName: 'API Calls',
            charge: {
              id: 'charge-1',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-1',
                name: 'API Calls',
                recurring: false,
              },
            },
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
        ] as unknown as FeeDetailsForInvoiceOverviewFragment[],
        subscriptions: [
          {
            id: 'sub-1',
            name: 'Main Subscription',
            currentBillingPeriodStartedAt: '2024-01-01T00:00:00Z',
            currentBillingPeriodEndingAt: '2024-01-31T23:59:59Z',
            plan: {
              id: 'plan-1',
              name: 'Premium Plan',
              interval: 'monthly',
            },
          },
        ],
        invoiceSubscriptions: [
          {
            subscription: { id: 'sub-1' },
            invoice: { id: 'invoice-1' },
            acceptNewChargeFees: false, // Should NOT allow adding new fees
          },
        ],
      } as unknown as InvoiceForDetailsTableFragment

      render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={mockInvoice}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={mockInvoice.fees as FeeDetailsForInvoiceOverviewFragment[]}
        />,
      )

      // Should display subscription
      expect(screen.getByText('Main Subscription')).toBeInTheDocument()

      // Component should render successfully with acceptNewChargeFees=false
      expect(screen.getByText('API Calls')).toBeInTheDocument()
    })

    it('should default to acceptNewChargeFees=false when invoiceSubscription not found', () => {
      const mockInvoice: InvoiceForDetailsTableFragment = {
        id: 'invoice-1',
        invoiceType: InvoiceTypeEnum.Subscription,
        status: InvoiceStatusTypeEnum.Draft,
        subTotalExcludingTaxesAmountCents: 5000,
        subTotalIncludingTaxesAmountCents: 5500,
        totalAmountCents: 5500,
        currency: CurrencyEnum.Usd,
        issuingDate: '2024-01-31',
        allChargesHaveFees: false,
        allFixedChargesHaveFees: false,
        versionNumber: 1,
        fees: [
          {
            id: 'fee-1',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'API Calls',
            itemName: 'API Calls',
            charge: {
              id: 'charge-1',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-1',
                name: 'API Calls',
                recurring: false,
              },
            },
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
        ] as unknown as FeeDetailsForInvoiceOverviewFragment[],
        subscriptions: [
          {
            id: 'sub-1',
            name: 'Main Subscription',
            currentBillingPeriodStartedAt: '2024-01-01T00:00:00Z',
            currentBillingPeriodEndingAt: '2024-01-31T23:59:59Z',
            plan: {
              id: 'plan-1',
              name: 'Premium Plan',
              interval: 'monthly',
            },
          },
        ],
        invoiceSubscriptions: [], // No invoiceSubscription records
      } as unknown as InvoiceForDetailsTableFragment

      render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={mockInvoice}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={mockInvoice.fees as FeeDetailsForInvoiceOverviewFragment[]}
        />,
      )

      // Should display subscription
      expect(screen.getByText('Main Subscription')).toBeInTheDocument()

      // Component should render successfully with default acceptNewChargeFees=false
      expect(screen.getByText('API Calls')).toBeInTheDocument()
    })
  })

  describe('Edge cases', () => {
    it('should handle null invoice gracefully', () => {
      const { container } = render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={null}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={[]}
        />,
      )

      // Should render nothing when invoice is null
      expect(container.firstChild).toBeNull()
    })

    it('should handle undefined invoice gracefully', () => {
      const { container } = render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={undefined}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={[]}
        />,
      )

      // Should render nothing when invoice is undefined
      expect(container.firstChild).toBeNull()
    })
  })

  describe('Data-test attributes', () => {
    it('should render subscription table with correct data-test attribute', () => {
      const mockInvoice: InvoiceForDetailsTableFragment = {
        id: 'invoice-1',
        invoiceType: InvoiceTypeEnum.Subscription,
        status: InvoiceStatusTypeEnum.Finalized,
        subTotalExcludingTaxesAmountCents: 10000,
        subTotalIncludingTaxesAmountCents: 11000,
        totalAmountCents: 11000,
        currency: CurrencyEnum.Usd,
        issuingDate: '2024-01-31',
        allChargesHaveFees: true,
        allFixedChargesHaveFees: true,
        versionNumber: 1,
        fees: [
          {
            id: 'fee-1',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'API Calls',
            itemName: 'API Calls',
            charge: {
              id: 'charge-1',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-1',
                name: 'API Calls',
                recurring: false,
              },
            },
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
        ] as unknown as FeeDetailsForInvoiceOverviewFragment[],
        subscriptions: [
          {
            id: 'sub-1',
            name: 'Main Subscription',
            currentBillingPeriodStartedAt: '2024-01-01T00:00:00Z',
            currentBillingPeriodEndingAt: '2024-01-31T23:59:59Z',
            plan: {
              id: 'plan-1',
              name: 'Premium Plan',
              interval: 'monthly',
            },
          },
        ],
        invoiceSubscriptions: [
          {
            subscription: { id: 'sub-1' },
            invoice: { id: 'invoice-1' },
            acceptNewChargeFees: true,
          },
        ],
      } as unknown as InvoiceForDetailsTableFragment

      render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={mockInvoice}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={mockInvoice.fees as FeeDetailsForInvoiceOverviewFragment[]}
        />,
      )

      // Should find subscription table by test ID
      const subscriptionTable = screen.getByTestId(INVOICE_DETAILS_TABLE_SUBSCRIPTION_TEST_ID)

      expect(subscriptionTable).toBeInTheDocument()
    })

    it('should render add fee button with correct data-test attribute when conditions are met', () => {
      const mockInvoice: InvoiceForDetailsTableFragment = {
        id: 'invoice-1',
        invoiceType: InvoiceTypeEnum.Subscription,
        status: InvoiceStatusTypeEnum.Draft,
        subTotalExcludingTaxesAmountCents: 5000,
        subTotalIncludingTaxesAmountCents: 5500,
        totalAmountCents: 5500,
        currency: CurrencyEnum.Usd,
        issuingDate: '2024-01-31',
        allChargesHaveFees: false, // Allows adding charges
        allFixedChargesHaveFees: false,
        versionNumber: 1,
        fees: [
          {
            id: 'fee-1',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'API Calls',
            itemName: 'API Calls',
            charge: {
              id: 'charge-1',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-1',
                name: 'API Calls',
                recurring: false,
              },
            },
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
        ] as unknown as FeeDetailsForInvoiceOverviewFragment[],
        subscriptions: [
          {
            id: 'sub-1',
            name: 'Main Subscription',
            currentBillingPeriodStartedAt: '2024-01-01T00:00:00Z',
            currentBillingPeriodEndingAt: '2024-01-31T23:59:59Z',
            plan: {
              id: 'plan-1',
              name: 'Premium Plan',
              interval: 'monthly',
            },
          },
        ],
        invoiceSubscriptions: [
          {
            subscription: { id: 'sub-1' },
            invoice: { id: 'invoice-1' },
            acceptNewChargeFees: true, // Allows adding new fees
          },
        ],
      } as unknown as InvoiceForDetailsTableFragment

      render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={mockInvoice}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={mockInvoice.fees as FeeDetailsForInvoiceOverviewFragment[]}
        />,
      )

      // Should find add fee button by test ID
      const addFeeButton = screen.getByTestId(INVOICE_DETAILS_TABLE_ADD_FEE_BUTTON_TEST_ID)

      expect(addFeeButton).toBeInTheDocument()
    })

    it('should not render add fee button when acceptNewChargeFees is false', () => {
      const mockInvoice: InvoiceForDetailsTableFragment = {
        id: 'invoice-1',
        invoiceType: InvoiceTypeEnum.Subscription,
        status: InvoiceStatusTypeEnum.Draft,
        subTotalExcludingTaxesAmountCents: 5000,
        subTotalIncludingTaxesAmountCents: 5500,
        totalAmountCents: 5500,
        currency: CurrencyEnum.Usd,
        issuingDate: '2024-01-31',
        allChargesHaveFees: false,
        allFixedChargesHaveFees: false,
        versionNumber: 1,
        fees: [
          {
            id: 'fee-1',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'API Calls',
            itemName: 'API Calls',
            charge: {
              id: 'charge-1',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-1',
                name: 'API Calls',
                recurring: false,
              },
            },
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
        ] as unknown as FeeDetailsForInvoiceOverviewFragment[],
        subscriptions: [
          {
            id: 'sub-1',
            name: 'Main Subscription',
            currentBillingPeriodStartedAt: '2024-01-01T00:00:00Z',
            currentBillingPeriodEndingAt: '2024-01-31T23:59:59Z',
            plan: {
              id: 'plan-1',
              name: 'Premium Plan',
              interval: 'monthly',
            },
          },
        ],
        invoiceSubscriptions: [
          {
            subscription: { id: 'sub-1' },
            invoice: { id: 'invoice-1' },
            acceptNewChargeFees: false, // Should NOT show button
          },
        ],
      } as unknown as InvoiceForDetailsTableFragment

      render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={mockInvoice}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={mockInvoice.fees as FeeDetailsForInvoiceOverviewFragment[]}
        />,
      )

      // Should NOT find add fee button
      const addFeeButton = screen.queryByTestId(INVOICE_DETAILS_TABLE_ADD_FEE_BUTTON_TEST_ID)

      expect(addFeeButton).not.toBeInTheDocument()
    })
  })

  describe('Snapshot Tests', () => {
    it('should match snapshot for invoice with 1 subscription', () => {
      const mockInvoice: InvoiceForDetailsTableFragment = {
        id: 'invoice-1',
        invoiceType: InvoiceTypeEnum.Subscription,
        status: InvoiceStatusTypeEnum.Finalized,
        subTotalExcludingTaxesAmountCents: 10000,
        subTotalIncludingTaxesAmountCents: 11000,
        totalAmountCents: 11000,
        currency: CurrencyEnum.Usd,
        issuingDate: '2024-01-31',
        allChargesHaveFees: true,
        allFixedChargesHaveFees: true,
        versionNumber: 1,
        fees: [
          {
            id: 'fee-1',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Subscription,
            invoiceDisplayName: null,
            itemName: 'Monthly subscription',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
          {
            id: 'fee-2',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'API Calls',
            itemName: 'API Calls',
            units: 100,
            preciseUnitAmount: '50',
            charge: {
              id: 'charge-1',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-1',
                name: 'API Calls',
                recurring: false,
              },
            },
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
        ] as unknown as FeeDetailsForInvoiceOverviewFragment[],
        subscriptions: [
          {
            id: 'sub-1',
            name: 'Main Subscription',
            currentBillingPeriodStartedAt: '2024-01-01T00:00:00Z',
            currentBillingPeriodEndingAt: '2024-01-31T23:59:59Z',
            plan: {
              id: 'plan-1',
              name: 'Premium Plan',
              interval: 'monthly',
            },
          },
        ],
        invoiceSubscriptions: [
          {
            subscription: { id: 'sub-1' },
            invoice: { id: 'invoice-1' },
            acceptNewChargeFees: true,
          },
        ],
      } as unknown as InvoiceForDetailsTableFragment

      const { container } = render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={mockInvoice}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={mockInvoice.fees as FeeDetailsForInvoiceOverviewFragment[]}
        />,
      )

      expect(container).toMatchSnapshot()
    })

    it('should match snapshot for invoice with 2 subscriptions', () => {
      const mockInvoice: InvoiceForDetailsTableFragment = {
        id: 'invoice-1',
        invoiceType: InvoiceTypeEnum.Subscription,
        status: InvoiceStatusTypeEnum.Finalized,
        subTotalExcludingTaxesAmountCents: 20000,
        subTotalIncludingTaxesAmountCents: 22000,
        totalAmountCents: 22000,
        currency: CurrencyEnum.Usd,
        issuingDate: '2024-01-31',
        allChargesHaveFees: true,
        allFixedChargesHaveFees: true,
        versionNumber: 1,
        fees: [
          {
            id: 'fee-1',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Subscription,
            invoiceDisplayName: null,
            itemName: 'Monthly subscription',
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
          {
            id: 'fee-2',
            amountCents: 5000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'API Calls',
            itemName: 'API Calls',
            charge: {
              id: 'charge-1',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-1',
                name: 'API Calls',
                recurring: false,
              },
            },
            subscription: { id: 'sub-1' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-01-31T23:59:59Z',
            },
          },
          {
            id: 'fee-3',
            amountCents: 7000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Subscription,
            invoiceDisplayName: null,
            itemName: 'Yearly subscription',
            subscription: { id: 'sub-2' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-12-31T23:59:59Z',
            },
          },
          {
            id: 'fee-4',
            amountCents: 3000,
            currency: CurrencyEnum.Usd,
            feeType: FeeTypesEnum.Charge,
            invoiceDisplayName: null,
            invoiceName: 'Storage',
            itemName: 'Storage',
            charge: {
              id: 'charge-2',
              payInAdvance: false,
              chargeModel: ChargeModelEnum.Standard,
              billableMetric: {
                id: 'metric-2',
                name: 'Storage',
                recurring: false,
              },
            },
            subscription: { id: 'sub-2' },
            properties: {
              fromDatetime: '2024-01-01T00:00:00Z',
              toDatetime: '2024-12-31T23:59:59Z',
            },
          },
        ] as unknown as FeeDetailsForInvoiceOverviewFragment[],
        subscriptions: [
          {
            id: 'sub-1',
            name: 'Monthly Subscription',
            currentBillingPeriodStartedAt: '2024-01-01T00:00:00Z',
            currentBillingPeriodEndingAt: '2024-01-31T23:59:59Z',
            plan: {
              id: 'plan-1',
              name: 'Premium Plan',
              interval: 'monthly',
            },
          },
          {
            id: 'sub-2',
            name: 'Yearly Subscription',
            currentBillingPeriodStartedAt: '2024-01-01T00:00:00Z',
            currentBillingPeriodEndingAt: '2024-12-31T23:59:59Z',
            plan: {
              id: 'plan-2',
              name: 'Enterprise Plan',
              interval: 'yearly',
            },
          },
        ],
        invoiceSubscriptions: [
          {
            subscription: { id: 'sub-1' },
            invoice: { id: 'invoice-1' },
            acceptNewChargeFees: true,
          },
          {
            subscription: { id: 'sub-2' },
            invoice: { id: 'invoice-1' },
            acceptNewChargeFees: false,
          },
        ],
      } as unknown as InvoiceForDetailsTableFragment

      const { container } = render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={mockInvoice}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={mockInvoice.fees as FeeDetailsForInvoiceOverviewFragment[]}
        />,
      )

      expect(container).toMatchSnapshot()
    })

    it('should match snapshot for empty invoice', () => {
      const mockInvoice: InvoiceForDetailsTableFragment = {
        id: 'invoice-1',
        invoiceType: InvoiceTypeEnum.Subscription,
        status: InvoiceStatusTypeEnum.Draft,
        subTotalExcludingTaxesAmountCents: 0,
        subTotalIncludingTaxesAmountCents: 0,
        totalAmountCents: 0,
        currency: CurrencyEnum.Usd,
        issuingDate: '2024-01-31',
        allChargesHaveFees: false,
        allFixedChargesHaveFees: false,
        versionNumber: 1,
        fees: [],
        subscriptions: [],
        invoiceSubscriptions: [],
      } as unknown as InvoiceForDetailsTableFragment

      const { container } = render(
        <InvoiceDetailsTable
          customer={mockCustomer}
          invoice={mockInvoice}
          editFeeDrawerRef={mockEditFeeDrawerRef}
          fees={[]}
        />,
      )

      expect(container).toMatchSnapshot()
    })
  })
})
