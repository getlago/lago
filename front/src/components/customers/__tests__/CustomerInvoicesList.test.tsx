import { render, screen } from '@testing-library/react'

import {
  CurrencyEnum,
  InvoiceForInvoiceListFragment,
  InvoicePaymentStatusTypeEnum,
  InvoiceStatusTypeEnum,
  InvoiceTypeEnum,
  TimezoneEnum,
} from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { CustomerInvoicesList } from '../CustomerInvoicesList'

// Mock IntersectionObserver for InfiniteScroll component
const mockIntersectionObserver = jest.fn()

mockIntersectionObserver.mockReturnValue({
  observe: () => null,
  unobserve: () => null,
  disconnect: () => null,
})
window.IntersectionObserver = mockIntersectionObserver

jest.mock('~/hooks/usePermissionsInvoiceActions', () => ({
  usePermissionsInvoiceActions: () => ({
    canDownload: () => true,
    canFinalize: () => false,
    canRetryCollect: () => false,
    canGeneratePaymentUrl: () => false,
    canUpdatePaymentStatus: () => false,
    canVoid: () => false,
    canIssueCreditNote: () => false,
    canRecordPayment: () => false,
    canResendEmail: () => false,
    canRegenerate: () => false,
  }),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: true }),
}))

const createMockInvoice = (
  overrides?: Partial<InvoiceForInvoiceListFragment['collection'][number]>,
): InvoiceForInvoiceListFragment['collection'][number] => ({
  id: 'invoice-1',
  status: InvoiceStatusTypeEnum.Finalized,
  taxStatus: null,
  paymentStatus: InvoicePaymentStatusTypeEnum.Pending,
  paymentOverdue: false,
  number: 'INV-001',
  issuingDate: '2024-01-15',
  totalAmountCents: '10000',
  totalDueAmountCents: '10000',
  totalPaidAmountCents: '0',
  currency: CurrencyEnum.Eur,
  voidable: true,
  paymentDisputeLostAt: null,
  taxProviderVoidable: false,
  invoiceType: InvoiceTypeEnum.Subscription,
  creditableAmountCents: '10000',
  refundableAmountCents: '0',
  offsettableAmountCents: '0',
  associatedActiveWalletPresent: false,
  voidedInvoiceId: null,
  regeneratedInvoiceId: null,
  customer: {
    id: 'customer-1',
    externalId: 'ext-1',
    name: 'Test Customer',
    displayName: 'Test Customer',
    applicableTimezone: TimezoneEnum.TzUtc,
    paymentProvider: null,
    hasActiveWallet: false,
  },
  errorDetails: [],
  billingEntity: {
    id: 'billing-1',
    name: 'Billing Entity',
    code: 'BE-001',
    einvoicing: false,
  },
  ...overrides,
})

const createMockInvoiceData = (
  invoices: InvoiceForInvoiceListFragment['collection'] = [],
): InvoiceForInvoiceListFragment => ({
  collection: invoices,
  metadata: {
    currentPage: 1,
    totalCount: invoices.length,
    totalPages: 1,
  },
})

const defaultProps = {
  isLoading: false,
  customerId: 'customer-1',
}

const renderComponent = (props = {}) => {
  return render(<CustomerInvoicesList {...defaultProps} {...props} />, {
    wrapper: AllTheProviders,
  })
}

describe('CustomerInvoicesList', () => {
  describe('GIVEN invoices data', () => {
    it('THEN should render invoices in the table', () => {
      const invoices = [
        createMockInvoice({ id: 'inv-1', number: 'INV-001' }),
        createMockInvoice({ id: 'inv-2', number: 'INV-002' }),
      ]

      renderComponent({ invoiceData: createMockInvoiceData(invoices) })

      expect(screen.getByText('INV-001')).toBeInTheDocument()
      expect(screen.getByText('INV-002')).toBeInTheDocument()
    })
  })

  describe('GIVEN no invoices', () => {
    it('THEN should show empty state', () => {
      renderComponent({ invoiceData: createMockInvoiceData([]) })

      expect(screen.getByText('empty.svg')).toBeInTheDocument()
    })
  })

  describe('GIVEN loading state', () => {
    it('THEN should show loading rows', () => {
      renderComponent({ isLoading: true, invoiceData: createMockInvoiceData([]) })

      const bodyRows = screen.queryAllByRole('rowgroup')[1]

      expect(bodyRows?.querySelectorAll('tr').length).toBeGreaterThan(0)
    })
  })
})
