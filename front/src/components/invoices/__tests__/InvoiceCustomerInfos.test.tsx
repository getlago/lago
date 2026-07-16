import { screen } from '@testing-library/react'
import { Settings } from 'luxon'

import { InvoiceCustomerInfos } from '~/components/invoices/InvoiceCustomerInfos'
import {
  CountryCode,
  CustomerAccountTypeEnum,
  InvoiceForInvoiceInfosFragment,
  InvoicePaymentStatusTypeEnum,
  InvoiceStatusTypeEnum,
  InvoiceTypeEnum,
  TimezoneEnum,
} from '~/generated/graphql'
import { render } from '~/test-utils'

const originalDefaultZone = Settings.defaultZone

describe('InvoiceCustomerInfos', () => {
  beforeAll(() => {
    Settings.defaultZone = 'UTC'
  })

  afterAll(() => {
    Settings.defaultZone = originalDefaultZone
  })

  const createMockInvoice = (
    overrides?: Partial<InvoiceForInvoiceInfosFragment>,
  ): InvoiceForInvoiceInfosFragment => ({
    number: 'INV-001',
    invoiceType: InvoiceTypeEnum.OneOff,
    issuingDate: '2024-01-15',
    paymentDueDate: '2024-02-15',
    paymentOverdue: false,
    status: InvoiceStatusTypeEnum.Finalized,
    totalPaidAmountCents: '0',
    totalDueAmountCents: '10000',
    paymentStatus: InvoicePaymentStatusTypeEnum.Pending,
    paymentDisputeLostAt: null,
    taxProviderVoidable: false,
    errorDetails: [],
    customer: {
      id: 'customer-1',
      name: 'Acme Inc',
      displayName: 'Acme Corporation',
      legalNumber: 'LN-123456',
      legalName: 'Acme Corporation Legal',
      taxIdentificationNumber: 'TAX-789',
      email: 'billing@acme.com',
      addressLine1: '123 Main Street',
      addressLine2: 'Suite 100',
      state: 'California',
      country: CountryCode.Us,
      city: 'San Francisco',
      zipcode: '94102',
      applicableTimezone: TimezoneEnum.TzAmericaLosAngeles,
      deletedAt: null,
      accountType: CustomerAccountTypeEnum.Customer,
    },
    ...overrides,
  })

  describe('rendering', () => {
    it('should render invoice with full customer information', () => {
      const mockInvoice = createMockInvoice()

      render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      // Customer info
      expect(screen.getByText('Acme Corporation')).toBeInTheDocument()
      expect(screen.getByText('Acme Corporation Legal')).toBeInTheDocument()
      expect(screen.getByText('LN-123456')).toBeInTheDocument()
      expect(screen.getByText('billing@acme.com')).toBeInTheDocument()
      expect(screen.getByText('TAX-789')).toBeInTheDocument()

      // Invoice info
      expect(screen.getByText('INV-001')).toBeInTheDocument()
    })

    it('should render invoice with minimal customer information', () => {
      const mockInvoice = createMockInvoice({
        customer: {
          id: 'customer-2',
          name: null,
          displayName: 'Simple Customer',
          legalNumber: null,
          legalName: null,
          taxIdentificationNumber: null,
          email: null,
          addressLine1: null,
          addressLine2: null,
          state: null,
          country: null,
          city: null,
          zipcode: null,
          applicableTimezone: TimezoneEnum.TzUtc,
          deletedAt: null,
          accountType: CustomerAccountTypeEnum.Customer,
        },
      })

      render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      expect(screen.getByText('Simple Customer')).toBeInTheDocument()
      expect(screen.queryByText('LN-123456')).not.toBeInTheDocument()
    })

    it('should render partner customer label', () => {
      const mockInvoice = createMockInvoice({
        customer: {
          id: 'partner-1',
          name: 'Partner Company',
          displayName: 'Partner Company Display',
          legalNumber: null,
          legalName: null,
          taxIdentificationNumber: null,
          email: null,
          addressLine1: null,
          addressLine2: null,
          state: null,
          country: null,
          city: null,
          zipcode: null,
          applicableTimezone: TimezoneEnum.TzUtc,
          deletedAt: null,
          accountType: CustomerAccountTypeEnum.Partner,
        },
      })

      render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      expect(screen.getByText('Partner Company Display')).toBeInTheDocument()
    })

    it('should not render customer link when customer is deleted', () => {
      const mockInvoice = createMockInvoice({
        customer: {
          id: 'deleted-customer',
          name: 'Deleted Customer',
          displayName: 'Deleted Customer Display',
          legalNumber: null,
          legalName: null,
          taxIdentificationNumber: null,
          email: null,
          addressLine1: null,
          addressLine2: null,
          state: null,
          country: null,
          city: null,
          zipcode: null,
          applicableTimezone: TimezoneEnum.TzUtc,
          deletedAt: '2024-01-01T00:00:00Z',
          accountType: CustomerAccountTypeEnum.Customer,
        },
      })

      render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      expect(screen.getByText('Deleted Customer Display')).toBeInTheDocument()
      // The customer name should not be a link
      expect(
        screen.queryByRole('link', { name: 'Deleted Customer Display' }),
      ).not.toBeInTheDocument()
    })

    it('should render customer link when customer is not deleted', () => {
      const mockInvoice = createMockInvoice()

      render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      expect(screen.getByRole('link', { name: 'Acme Corporation' })).toBeInTheDocument()
    })

    it('should render overdue status when payment is overdue', () => {
      const mockInvoice = createMockInvoice({
        paymentOverdue: true,
      })

      render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      expect(screen.getByText('Overdue')).toBeInTheDocument()
    })

    it('should render payment dispute lost information', () => {
      const mockInvoice = createMockInvoice({
        paymentDisputeLostAt: '2024-01-20T00:00:00Z',
      })

      render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      // Check that the dispute info is rendered (date may vary due to timezone)
      expect(screen.getByText(/Dispute lost on/)).toBeInTheDocument()
    })

    it('should render dash for payment status when invoice is draft', () => {
      const mockInvoice = createMockInvoice({
        invoiceType: InvoiceTypeEnum.Subscription,
        status: InvoiceStatusTypeEnum.Draft,
      })

      render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      expect(screen.getByText('-')).toBeInTheDocument()
    })

    it('should format multiple emails with comma and space', () => {
      const mockInvoice = createMockInvoice({
        customer: {
          id: 'customer-multi-email',
          name: 'Multi Email Customer',
          displayName: 'Multi Email Customer',
          legalNumber: null,
          legalName: null,
          taxIdentificationNumber: null,
          email: 'email1@test.com,email2@test.com,email3@test.com',
          addressLine1: null,
          addressLine2: null,
          state: null,
          country: null,
          city: null,
          zipcode: null,
          applicableTimezone: TimezoneEnum.TzUtc,
          deletedAt: null,
          accountType: CustomerAccountTypeEnum.Customer,
        },
      })

      render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      expect(
        screen.getByText('email1@test.com, email2@test.com, email3@test.com'),
      ).toBeInTheDocument()
    })

    it('should render purchase order number for one-off invoices', () => {
      const mockInvoice = createMockInvoice({
        invoiceType: InvoiceTypeEnum.OneOff,
        purchaseOrderNumber: 'PO-12345',
      })

      render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      expect(screen.getByText('PO-12345')).toBeInTheDocument()
    })

    it('should not render the purchase order number row for non one-off invoices', () => {
      const mockInvoice = createMockInvoice({
        invoiceType: InvoiceTypeEnum.Subscription,
        purchaseOrderNumber: 'PO-12345',
      })

      render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      expect(screen.queryByText('PO number')).not.toBeInTheDocument()
      expect(screen.queryByText('PO-12345')).not.toBeInTheDocument()
    })

    it('should handle null invoice gracefully', () => {
      const { container } = render(<InvoiceCustomerInfos invoice={null} />)

      expect(container).toBeInTheDocument()
    })

    it('should handle undefined invoice gracefully', () => {
      const { container } = render(<InvoiceCustomerInfos invoice={undefined} />)

      expect(container).toBeInTheDocument()
    })
  })

  describe('Snapshot Tests', () => {
    it('should match snapshot for invoice with full customer information', () => {
      const mockInvoice = createMockInvoice()

      const { container } = render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      expect(container).toMatchSnapshot()
    })

    it('should match snapshot for invoice with minimal customer information', () => {
      const mockInvoice = createMockInvoice({
        number: 'INV-MINIMAL',
        customer: {
          id: 'customer-minimal',
          name: null,
          displayName: 'Minimal Customer',
          legalNumber: null,
          legalName: null,
          taxIdentificationNumber: null,
          email: null,
          addressLine1: null,
          addressLine2: null,
          state: null,
          country: null,
          city: null,
          zipcode: null,
          applicableTimezone: TimezoneEnum.TzUtc,
          deletedAt: null,
          accountType: CustomerAccountTypeEnum.Customer,
        },
      })

      const { container } = render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      expect(container).toMatchSnapshot()
    })

    it('should match snapshot for partner customer', () => {
      const mockInvoice = createMockInvoice({
        number: 'INV-PARTNER',
        customer: {
          id: 'partner-customer',
          name: 'Partner Corp',
          displayName: 'Partner Corporation',
          legalNumber: 'PARTNER-001',
          legalName: 'Partner Corp Legal',
          taxIdentificationNumber: 'PARTNER-TAX',
          email: 'partner@example.com',
          addressLine1: '456 Partner Ave',
          addressLine2: null,
          state: 'New York',
          country: CountryCode.Us,
          city: 'New York City',
          zipcode: '10001',
          applicableTimezone: TimezoneEnum.TzAmericaNewYork,
          deletedAt: null,
          accountType: CustomerAccountTypeEnum.Partner,
        },
      })

      const { container } = render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      expect(container).toMatchSnapshot()
    })

    it('should match snapshot for deleted customer', () => {
      const mockInvoice = createMockInvoice({
        number: 'INV-DELETED',
        customer: {
          id: 'deleted-customer',
          name: 'Deleted Corp',
          displayName: 'Deleted Corporation',
          legalNumber: null,
          legalName: null,
          taxIdentificationNumber: null,
          email: 'deleted@example.com',
          addressLine1: null,
          addressLine2: null,
          state: null,
          country: null,
          city: null,
          zipcode: null,
          applicableTimezone: TimezoneEnum.TzUtc,
          deletedAt: '2024-01-01T00:00:00Z',
          accountType: CustomerAccountTypeEnum.Customer,
        },
      })

      const { container } = render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      expect(container).toMatchSnapshot()
    })

    it('should match snapshot for overdue invoice', () => {
      const mockInvoice = createMockInvoice({
        number: 'INV-OVERDUE',
        paymentOverdue: true,
        paymentDueDate: '2024-01-01',
      })

      const { container } = render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      expect(container).toMatchSnapshot()
    })

    it('should match snapshot for draft invoice', () => {
      const mockInvoice = createMockInvoice({
        number: 'INV-DRAFT',
        status: InvoiceStatusTypeEnum.Draft,
        paymentStatus: InvoicePaymentStatusTypeEnum.Pending,
      })

      const { container } = render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      expect(container).toMatchSnapshot()
    })

    it('should match snapshot for invoice with payment dispute lost', () => {
      const mockInvoice = createMockInvoice({
        number: 'INV-DISPUTE',
        paymentDisputeLostAt: '2024-01-20T00:00:00Z',
      })

      const { container } = render(<InvoiceCustomerInfos invoice={mockInvoice} />)

      expect(container).toMatchSnapshot()
    })

    it('should match snapshot for null invoice', () => {
      const { container } = render(<InvoiceCustomerInfos invoice={null} />)

      expect(container).toMatchSnapshot()
    })
  })
})
