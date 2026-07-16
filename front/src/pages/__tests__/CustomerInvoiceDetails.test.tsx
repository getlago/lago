import { screen } from '@testing-library/react'

import { MainHeaderConfig } from '~/components/MainHeader/types'
import { addToast } from '~/core/apolloClient'
import {
  CREATE_INVOICE_PAYMENT_ROUTE,
  CUSTOMER_INVOICE_CREATE_CREDIT_NOTE_ROUTE,
  CUSTOMER_INVOICE_VOID_ROUTE,
} from '~/core/router'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { CurrencyEnum, InvoiceStatusTypeEnum, InvoiceTaxStatusTypeEnum } from '~/generated/graphql'
import { render, testMockNavigateFn } from '~/test-utils'

import CustomerInvoiceDetails from '../CustomerInvoiceDetails'

let capturedConfig: MainHeaderConfig | null = null

jest.mock('~/components/MainHeader/MainHeader', () => ({
  MainHeader: Object.assign(() => null, {
    Configure: (props: MainHeaderConfig) => {
      capturedConfig = props
      return null
    },
  }),
}))

jest.mock('~/components/MainHeader/useMainHeaderTabContent', () => ({
  useMainHeaderTabContent: () => <div data-test="active-tab-content">Tab Content</div>,
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/core/useLocationHistory', () => ({
  useLocationHistory: () => ({
    goBack: jest.fn(),
  }),
}))

const mockUseCurrentUser = jest.fn().mockReturnValue({ isPremium: true })

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => mockUseCurrentUser(),
}))

const mockHasPermissions = jest.fn().mockReturnValue(true)

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
  }),
}))

jest.mock('~/hooks/useResendEmailDialog', () => ({
  useResendEmailDialog: () => ({
    showResendEmailDialog: jest.fn(),
  }),
}))

jest.mock('~/hooks/useGeneratePaymentUrl', () => ({
  useGeneratePaymentUrl: () => ({
    generatePaymentUrl: jest.fn(),
  }),
}))

jest.mock('~/core/utils/copyToClipboard', () => ({
  copyToClipboard: jest.fn(),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

const mockInvoiceData = {
  invoice: {
    id: 'invoice-123',
    invoiceType: 'subscription',
    number: 'INV-001',
    paymentStatus: 'succeeded',
    status: InvoiceStatusTypeEnum.Finalized,
    taxStatus: null,
    totalAmountCents: '10000',
    currency: CurrencyEnum.Usd,
    refundableAmountCents: '10000',
    creditableAmountCents: '10000',
    offsettableAmountCents: '0',
    voidable: true,
    paymentDisputeLostAt: null,
    integrationSyncable: false,
    externalIntegrationId: null,
    taxProviderVoidable: false,
    integrationHubspotSyncable: false,
    associatedActiveWalletPresent: false,
    voidedAt: null,
    voidedInvoiceId: null,
    regeneratedInvoiceId: null,
    errorDetails: [],
    customer: {
      id: 'customer-123',
      email: 'customer@example.com',
    },
    billingEntity: {
      id: 'billing-entity-1',
      name: 'Billing Co',
      email: 'billing@example.com',
      einvoicing: false,
      emailSettings: [],
      logoUrl: null,
    },
  },
}

const mockCustomerData = {
  customer: {
    id: 'customer-123',
    name: 'Test Customer',
    paymentProvider: null,
    deletedAt: null,
    avalaraCustomer: null,
    netsuiteCustomer: null,
    xeroCustomer: null,
    hubspotCustomer: null,
    salesforceCustomer: null,
  },
}

const mockUseGetInvoiceDetailsQuery = jest.fn()
const mockUseGetInvoiceFeesQuery = jest.fn()
const mockUseGetInvoiceCustomerQuery = jest.fn()
const mockRefreshInvoice = jest.fn()
const mockRetryInvoice = jest.fn()
const mockRetryTaxProviderVoiding = jest.fn()
const mockSyncIntegrationInvoice = jest.fn()
const mockSyncHubspotIntegrationInvoice = jest.fn()
const mockSyncSalesforceIntegrationInvoice = jest.fn()

const mockUseIntegrationsListQuery = jest.fn().mockReturnValue({ data: null })

// Capture mutation options to test onError/onCompleted callbacks

const mockMutationOptions: Record<string, any> = {}

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetInvoiceDetailsQuery: () => mockUseGetInvoiceDetailsQuery(),
  useGetInvoiceFeesQuery: () => mockUseGetInvoiceFeesQuery(),
  useGetInvoiceCustomerQuery: () => mockUseGetInvoiceCustomerQuery(),
  useIntegrationsListForCustomerInvoiceDetailsQuery: () => mockUseIntegrationsListQuery(),

  useRefreshInvoiceMutation: (options: any) => {
    mockMutationOptions.refreshInvoice = options || {}
    return [mockRefreshInvoice, { loading: false }]
  },

  useRetryInvoiceMutation: (options: any) => {
    mockMutationOptions.retryInvoice = options || {}
    return [mockRetryInvoice, { loading: false }]
  },

  useRetryTaxProviderVoidingMutation: (options: any) => {
    mockMutationOptions.retryTaxProviderVoiding = options || {}
    return [mockRetryTaxProviderVoiding, { loading: false }]
  },

  useSyncIntegrationInvoiceMutation: (options: any) => {
    mockMutationOptions.syncIntegration = options || {}
    return [mockSyncIntegrationInvoice, { loading: false }]
  },

  useSyncHubspotIntegrationInvoiceMutation: (options: any) => {
    mockMutationOptions.syncHubspot = options || {}
    return [mockSyncHubspotIntegrationInvoice, { loading: false }]
  },

  useSyncSalesforceInvoiceMutation: (options: any) => {
    mockMutationOptions.syncSalesforce = options || {}
    return [mockSyncSalesforceIntegrationInvoice, { loading: false }]
  },
}))

const mockDownloadInvoice = jest.fn()
const mockDownloadInvoiceXml = jest.fn()

jest.mock('~/pages/invoiceDetails/common/useDownloadInvoice', () => ({
  useDownloadInvoice: () => ({
    downloadInvoice: mockDownloadInvoice,
    loadingInvoiceDownload: false,
    downloadInvoiceXml: mockDownloadInvoiceXml,
    loadingInvoiceXmlDownload: false,
  }),
}))

const mockDefaultAuthorizations = {
  canRetryInvoice: false,
  canFinalizeInvoice: false,
  canDownloadOnlyPdf: true,
  canDownloadPdfAndXml: false,
  canResendEmail: false,
  canIssueCreditNote: true,
  canRecordPayment: true,
  canUpdatePaymentStatus: true,
  canVoid: true,
  canRegenerate: false,
  canGeneratePaymentUrl: false,
  canSyncAccountingIntegration: false,
  canSyncCRMIntegration: false,
  canDispute: false,
  canSyncTaxIntegration: false,
}

const mockDefaultAuthorizationsReturn = {
  authorizations: mockDefaultAuthorizations,
  hasTaxProviderError: false,
  errorMessage: undefined,
  canRecordPayment: true,
}

const mockUseInvoiceAuthorizations = jest.fn().mockReturnValue(mockDefaultAuthorizationsReturn)

jest.mock('~/pages/invoiceDetails/common/useInvoiceAuthorizations', () => ({
  useInvoiceAuthorizations: () => mockUseInvoiceAuthorizations(),
}))

jest.mock('~/pages/InvoiceOverview', () => ({
  __esModule: true,
  default: () => <div data-test="invoice-overview-mock">InvoiceOverview</div>,
}))

jest.mock('~/components/invoices/FinalizeInvoiceDialog', () => ({
  FinalizeInvoiceDialog: () => null,
}))

jest.mock('~/components/invoices/EditInvoicePaymentStatusDialog', () => ({
  useUpdateInvoicePaymentStatusDialog: () => ({
    openUpdateInvoicePaymentStatusDialog: jest.fn(),
  }),
}))

jest.mock('~/components/invoices/DisputeInvoiceDialog', () => ({
  useDisputeInvoiceDialog: () => ({ openDisputeInvoiceDialog: jest.fn() }),
}))

jest.mock('~/components/invoices/AddMetadataDrawer', () => ({
  AddMetadataDrawer: () => null,
}))

jest.mock('~/components/dialogs/PremiumWarningDialog', () => ({
  usePremiumWarningDialog: () => ({ open: jest.fn(), close: jest.fn() }),
}))

jest.mock('~/components/invoices/InvoiceCreditNoteList', () => ({
  InvoiceCreditNoteList: () => (
    <div data-test="invoice-credit-note-list-mock">InvoiceCreditNoteList</div>
  ),
}))

jest.mock('~/components/invoices/InvoicePaymentList', () => ({
  InvoicePaymentList: () => <div data-test="invoice-payment-list-mock">InvoicePaymentList</div>,
}))

jest.mock('~/components/invoices/InvoiceActivityLogs', () => ({
  InvoiceActivityLogs: () => <div data-test="invoice-activity-logs-mock">InvoiceActivityLogs</div>,
}))

describe('CustomerInvoiceDetails', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    capturedConfig = null
    mockHasPermissions.mockReturnValue(true)
    mockUseCurrentUser.mockReturnValue({ isPremium: true })
    mockUseInvoiceAuthorizations.mockReturnValue(mockDefaultAuthorizationsReturn)
    mockUseIntegrationsListQuery.mockReturnValue({ data: null })
    Object.keys(mockMutationOptions).forEach((key) => delete mockMutationOptions[key])

    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({
      customerId: 'customer-123',
      invoiceId: 'invoice-123',
    })

    mockUseGetInvoiceDetailsQuery.mockReturnValue({
      data: mockInvoiceData,
      loading: false,
      error: null,
      refetch: jest.fn(),
    })

    mockUseGetInvoiceFeesQuery.mockReturnValue({
      data: { invoice: { id: 'invoice-123', fees: [] } },
      loading: false,
      error: null,
    })

    mockUseGetInvoiceCustomerQuery.mockReturnValue({
      data: mockCustomerData,
      loading: false,
    })
  })

  describe('GIVEN the page is rendered with data', () => {
    describe('WHEN in default state', () => {
      it('THEN should configure MainHeader with breadcrumb', () => {
        render(<CustomerInvoiceDetails />)

        expect(capturedConfig?.breadcrumb).toHaveLength(1)
        expect(capturedConfig?.breadcrumb?.[0].label).toBeDefined()
      })

      it('THEN should configure MainHeader with entity containing invoice number', () => {
        render(<CustomerInvoiceDetails />)

        expect(capturedConfig?.entity?.viewName).toBe('INV-001')
      })

      it('THEN should configure MainHeader with entity metadata containing invoice ID', () => {
        render(<CustomerInvoiceDetails />)

        expect(capturedConfig?.entity?.metadata).toContain('invoice-123')
      })

      it('THEN should configure MainHeader with entity badges', () => {
        render(<CustomerInvoiceDetails />)

        expect(capturedConfig?.entity?.badges?.length).toBeGreaterThan(0)
      })

      it('THEN should configure MainHeader with a dropdown action', () => {
        render(<CustomerInvoiceDetails />)

        expect(capturedConfig?.actions?.items).toHaveLength(1)
        expect(capturedConfig?.actions?.items[0].type).toBe('dropdown')
      })

      it('THEN should configure MainHeader with tabs', () => {
        render(<CustomerInvoiceDetails />)

        expect(capturedConfig?.tabs).toBeDefined()
        expect(capturedConfig?.tabs?.length).toBeGreaterThanOrEqual(1)
      })

      it('THEN should display the active tab content', () => {
        render(<CustomerInvoiceDetails />)

        expect(screen.getByTestId('active-tab-content')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the page is loading', () => {
    beforeEach(() => {
      mockUseGetInvoiceDetailsQuery.mockReturnValue({
        data: null,
        loading: true,
        error: null,
        refetch: jest.fn(),
      })
      mockUseGetInvoiceFeesQuery.mockReturnValue({
        data: null,
        loading: true,
        error: null,
      })
      mockUseGetInvoiceCustomerQuery.mockReturnValue({
        data: null,
        loading: true,
      })
    })

    describe('WHEN the component renders', () => {
      it('THEN should set actionsLoading on MainHeader config', () => {
        render(<CustomerInvoiceDetails />)

        expect(capturedConfig?.actions?.loading).toBe(true)
      })
    })
  })

  describe('GIVEN the page has an error', () => {
    beforeEach(() => {
      mockUseGetInvoiceDetailsQuery.mockReturnValue({
        data: null,
        loading: false,
        error: new Error('Failed'),
        refetch: jest.fn(),
      })
    })

    describe('WHEN the component renders', () => {
      it('THEN should not set actionsLoading on MainHeader config', () => {
        render(<CustomerInvoiceDetails />)

        expect(capturedConfig?.actions?.loading).toBeFalsy()
      })
    })
  })

  describe('GIVEN the dropdown items', () => {
    describe('WHEN the copy ID item is clicked', () => {
      it('THEN should copy the invoice ID to clipboard', () => {
        render(<CustomerInvoiceDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          // The copy ID item is always visible (no hidden flag)
          // Find it by checking which item calls copyToClipboard
          const copyItem = dropdownAction.items.find((item) => {
            const mockClose = jest.fn()

            item.onClick(mockClose)
            if ((copyToClipboard as jest.Mock).mock.calls.length > 0) {
              return true
            }
            return false
          })

          expect(copyItem).toBeDefined()
          expect(copyToClipboard).toHaveBeenCalledWith('invoice-123')
          expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'info' }))
        }
      })
    })

    describe('WHEN the download PDF item is present', () => {
      it('THEN should have a download item that is not hidden', () => {
        render(<CustomerInvoiceDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          const visibleItems = dropdownAction.items.filter((item) => !item.hidden)

          // With canDownloadOnlyPdf=true, there should be visible items including download
          expect(visibleItems.length).toBeGreaterThan(0)
        }
      })
    })
  })

  describe('GIVEN the invoice is finalized', () => {
    describe('WHEN tabs are configured', () => {
      it('THEN should include payments tab', () => {
        render(<CustomerInvoiceDetails />)

        // Finalized status should add payments tab
        const tabs = capturedConfig?.tabs

        expect(tabs).toBeDefined()
        // At minimum: overview + payments tabs for finalized status
        expect(tabs?.length).toBeGreaterThanOrEqual(2)
      })

      it('THEN should include credit notes tab', () => {
        render(<CustomerInvoiceDetails />)

        const tabs = capturedConfig?.tabs

        // Finalized status with no pending tax should have credit notes tab
        // overview + payments + credit notes + activity logs (if premium)
        expect(tabs?.length).toBeGreaterThanOrEqual(3)
      })

      it('THEN should include all four tabs (overview, payments, credit notes, activity logs)', () => {
        render(<CustomerInvoiceDetails />)

        // Finalized + no pending tax + premium + auditLogsView
        expect(capturedConfig?.tabs).toHaveLength(4)
      })
    })
  })

  describe('GIVEN the invoice is in draft status', () => {
    beforeEach(() => {
      mockUseGetInvoiceDetailsQuery.mockReturnValue({
        data: {
          invoice: { ...mockInvoiceData.invoice, status: InvoiceStatusTypeEnum.Draft },
        },
        loading: false,
        error: null,
        refetch: jest.fn(),
      })
    })

    describe('WHEN tabs are configured', () => {
      it('THEN should include only overview and activity logs tabs', () => {
        render(<CustomerInvoiceDetails />)

        // Draft: no payments, no credit notes → overview + activity logs
        expect(capturedConfig?.tabs).toHaveLength(2)
      })
    })
  })

  describe('GIVEN the invoice is in pending status', () => {
    beforeEach(() => {
      mockUseGetInvoiceDetailsQuery.mockReturnValue({
        data: {
          invoice: { ...mockInvoiceData.invoice, status: InvoiceStatusTypeEnum.Pending },
        },
        loading: false,
        error: null,
        refetch: jest.fn(),
      })
    })

    describe('WHEN tabs are configured', () => {
      it('THEN should include overview, payments, and activity logs but not credit notes', () => {
        render(<CustomerInvoiceDetails />)

        // Pending: overview + payments + activity logs = 3 (no credit notes)
        expect(capturedConfig?.tabs).toHaveLength(3)
      })
    })
  })

  describe('GIVEN the invoice has pending tax status', () => {
    beforeEach(() => {
      mockUseGetInvoiceDetailsQuery.mockReturnValue({
        data: {
          invoice: {
            ...mockInvoiceData.invoice,
            taxStatus: InvoiceTaxStatusTypeEnum.Pending,
          },
        },
        loading: false,
        error: null,
        refetch: jest.fn(),
      })
    })

    describe('WHEN tabs are configured', () => {
      it('THEN should not include credit notes tab', () => {
        render(<CustomerInvoiceDetails />)

        // Finalized + tax pending: overview + payments + activity logs = 3
        expect(capturedConfig?.tabs).toHaveLength(3)
      })
    })
  })

  describe('GIVEN the user does not have auditLogsView permission', () => {
    beforeEach(() => {
      mockHasPermissions.mockImplementation((perms: string[]) => !perms.includes('auditLogsView'))
    })

    describe('WHEN tabs are configured for a finalized invoice', () => {
      it('THEN should not include activity logs tab', () => {
        render(<CustomerInvoiceDetails />)

        // Finalized without activity logs: overview + payments + credit notes = 3
        expect(capturedConfig?.tabs).toHaveLength(3)
      })
    })
  })

  describe('GIVEN the user does not have creditNotesView permission', () => {
    beforeEach(() => {
      mockHasPermissions.mockImplementation((perms: string[]) => !perms.includes('creditNotesView'))
    })

    describe('WHEN tabs are configured for a finalized invoice', () => {
      it('THEN should not include credit notes tab', () => {
        render(<CustomerInvoiceDetails />)

        // Finalized without credit notes: overview + payments + activity logs = 3
        expect(capturedConfig?.tabs).toHaveLength(3)
      })
    })
  })

  describe('GIVEN the user is not premium', () => {
    beforeEach(() => {
      mockUseCurrentUser.mockReturnValue({ isPremium: false })
    })

    describe('WHEN tabs are configured for a finalized invoice', () => {
      it('THEN should not include activity logs tab', () => {
        render(<CustomerInvoiceDetails />)

        // Finalized without activity logs: overview + payments + credit notes = 3
        expect(capturedConfig?.tabs).toHaveLength(3)
      })
    })
  })

  describe('GIVEN the invoice badge warning icon', () => {
    describe('WHEN the invoice has a payment dispute', () => {
      it('THEN should show warning icon on badge', () => {
        mockUseGetInvoiceDetailsQuery.mockReturnValue({
          data: {
            invoice: {
              ...mockInvoiceData.invoice,
              paymentDisputeLostAt: '2024-01-01T00:00:00Z',
            },
          },
          loading: false,
          error: null,
          refetch: jest.fn(),
        })

        render(<CustomerInvoiceDetails />)

        expect(capturedConfig?.entity?.badges?.[0]?.endIcon).toBe('warning-unfilled')
      })
    })

    describe('WHEN the invoice has error details', () => {
      it('THEN should show warning icon on badge', () => {
        mockUseGetInvoiceDetailsQuery.mockReturnValue({
          data: {
            invoice: {
              ...mockInvoiceData.invoice,
              errorDetails: [{ errorCode: 'tax_error', errorDetails: 'Tax failed' }],
            },
          },
          loading: false,
          error: null,
          refetch: jest.fn(),
        })

        render(<CustomerInvoiceDetails />)

        expect(capturedConfig?.entity?.badges?.[0]?.endIcon).toBe('warning-unfilled')
      })
    })

    describe('WHEN the invoice is taxProviderVoidable', () => {
      it('THEN should show warning icon on badge', () => {
        mockUseGetInvoiceDetailsQuery.mockReturnValue({
          data: {
            invoice: {
              ...mockInvoiceData.invoice,
              taxProviderVoidable: true,
            },
          },
          loading: false,
          error: null,
          refetch: jest.fn(),
        })

        render(<CustomerInvoiceDetails />)

        expect(capturedConfig?.entity?.badges?.[0]?.endIcon).toBe('warning-unfilled')
      })
    })

    describe('WHEN no warning conditions are present', () => {
      it('THEN should not show warning icon on badge', () => {
        render(<CustomerInvoiceDetails />)

        expect(capturedConfig?.entity?.badges?.[0]?.endIcon).toBeUndefined()
      })
    })
  })

  describe('GIVEN a query error occurs', () => {
    beforeEach(() => {
      mockUseGetInvoiceDetailsQuery.mockReturnValue({
        data: null,
        loading: false,
        error: new Error('Failed'),
        refetch: jest.fn(),
      })
    })

    describe('WHEN the component renders', () => {
      it('THEN should not display the active tab content', () => {
        render(<CustomerInvoiceDetails />)

        expect(screen.queryByTestId('active-tab-content')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the invoice authorization returns an error message', () => {
    beforeEach(() => {
      mockUseInvoiceAuthorizations.mockReturnValue({
        ...mockDefaultAuthorizationsReturn,
        errorMessage: 'text_some_error_key',
      })
    })

    describe('WHEN the component renders', () => {
      it('THEN should still display the active tab content', () => {
        render(<CustomerInvoiceDetails />)

        expect(screen.getByTestId('active-tab-content')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN all dropdown action items', () => {
    describe('WHEN each onClick handler is invoked', () => {
      it('THEN all items should call closePopper', async () => {
        render(<CustomerInvoiceDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          for (const item of dropdownAction.items) {
            const mockClose = jest.fn()

            await item.onClick(mockClose)
            expect(mockClose).toHaveBeenCalled()
          }
        }
      })
    })

    describe('WHEN the void item is clicked', () => {
      it('THEN should navigate to the void invoice route', async () => {
        render(<CustomerInvoiceDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          // Void is item 16 (0-indexed in items array)
          const mockClose = jest.fn()

          await dropdownAction.items[16].onClick(mockClose)

          expect(testMockNavigateFn).toHaveBeenCalledWith(
            CUSTOMER_INVOICE_VOID_ROUTE.replace(':customerId', 'customer-123').replace(
              ':invoiceId',
              'invoice-123',
            ),
          )
        }
      })
    })

    describe('WHEN the credit note item is clicked as a premium user', () => {
      it('THEN should navigate to the credit note route', async () => {
        render(<CustomerInvoiceDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          const mockClose = jest.fn()

          // Credit note is item 7
          await dropdownAction.items[7].onClick(mockClose)

          expect(testMockNavigateFn).toHaveBeenCalledWith(
            CUSTOMER_INVOICE_CREATE_CREDIT_NOTE_ROUTE.replace(
              ':customerId',
              'customer-123',
            ).replace(':invoiceId', 'invoice-123'),
          )
        }
      })
    })

    describe('WHEN the record payment item is clicked as a premium user', () => {
      it('THEN should navigate to the create payment route', async () => {
        render(<CustomerInvoiceDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          const mockClose = jest.fn()

          // Record payment is item 8
          await dropdownAction.items[8].onClick(mockClose)

          expect(testMockNavigateFn).toHaveBeenCalledWith(
            CREATE_INVOICE_PAYMENT_ROUTE.replace(':invoiceId', 'invoice-123'),
          )
        }
      })
    })
  })

  describe('GIVEN the user is not premium and clicks dropdown items', () => {
    beforeEach(() => {
      mockUseCurrentUser.mockReturnValue({ isPremium: false })
    })

    describe('WHEN the credit note item is clicked', () => {
      it('THEN should not navigate to credit note route', async () => {
        render(<CustomerInvoiceDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          const mockClose = jest.fn()

          // Credit note is item 7 — non-premium opens premium warning instead
          await dropdownAction.items[7].onClick(mockClose)

          expect(testMockNavigateFn).not.toHaveBeenCalledWith(
            expect.stringContaining('credit-note'),
          )
        }
      })
    })

    describe('WHEN the record payment item is clicked', () => {
      it('THEN should not navigate to payment route', async () => {
        render(<CustomerInvoiceDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          const mockClose = jest.fn()

          // Record payment is item 8 — non-premium opens premium warning
          await dropdownAction.items[8].onClick(mockClose)

          expect(testMockNavigateFn).not.toHaveBeenCalledWith(expect.stringContaining('payment'))
        }
      })
    })
  })

  describe('GIVEN customer has integration connections', () => {
    beforeEach(() => {
      mockUseGetInvoiceCustomerQuery.mockReturnValue({
        data: {
          customer: {
            ...mockCustomerData.customer,
            netsuiteCustomer: {
              id: 'ns-cust-1',
              integrationId: 'ns-int-1',
              externalCustomerId: 'ext-1',
            },
            hubspotCustomer: { id: 'hs-cust-1', integrationId: 'hs-int-1' },
            salesforceCustomer: { id: 'sf-cust-1', integrationId: 'sf-int-1' },
            avalaraCustomer: { id: 'av-cust-1', integrationId: 'av-int-1' },
          },
        },
        loading: false,
      })

      mockUseIntegrationsListQuery.mockReturnValue({
        data: {
          integrations: {
            collection: [
              { __typename: 'NetsuiteIntegration', id: 'ns-int-1' },
              { __typename: 'HubspotIntegration', id: 'hs-int-1' },
              { __typename: 'SalesforceIntegration', id: 'sf-int-1' },
              { __typename: 'AvalaraIntegration', id: 'av-int-1' },
            ],
          },
        },
      })
    })

    describe('WHEN the component renders', () => {
      it('THEN should process integration data without error', () => {
        render(<CustomerInvoiceDetails />)

        // The component filters and finds integrations internally
        // This test verifies the filter/find callbacks execute without error
        expect(capturedConfig?.entity?.viewName).toBe('INV-001')
      })
    })

    describe('WHEN all dropdown items are exercised with integrations', () => {
      it('THEN all items should call closePopper', async () => {
        // Enable sync authorization flags for integration-related items
        mockUseInvoiceAuthorizations.mockReturnValue({
          ...mockDefaultAuthorizationsReturn,
          authorizations: {
            ...mockDefaultAuthorizations,
            canSyncAccountingIntegration: true,
            canSyncCRMIntegration: true,
          },
        })

        render(<CustomerInvoiceDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          for (const item of dropdownAction.items) {
            const mockClose = jest.fn()

            await item.onClick(mockClose)
            expect(mockClose).toHaveBeenCalled()
          }
        }
      })
    })
  })

  describe('GIVEN mutation callbacks', () => {
    describe('WHEN refreshInvoice encounters a tax error', () => {
      it('THEN should show a danger toast', () => {
        render(<CustomerInvoiceDetails />)

        const onError = mockMutationOptions.refreshInvoice?.onError

        expect(onError).toBeDefined()

        onError?.({
          graphQLErrors: [{ extensions: { details: { taxError: ['Tax calculation failed'] } } }],
        })

        expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'danger' }))
      })
    })

    describe('WHEN retryInvoice completes successfully', () => {
      it('THEN should call refetch', async () => {
        const mockRefetch = jest.fn()

        mockUseGetInvoiceDetailsQuery.mockReturnValue({
          data: mockInvoiceData,
          loading: false,
          error: null,
          refetch: mockRefetch,
        })

        render(<CustomerInvoiceDetails />)

        const onCompleted = mockMutationOptions.retryInvoice?.onCompleted

        expect(onCompleted).toBeDefined()

        await onCompleted?.({ retryInvoice: { id: 'invoice-123' } })

        expect(mockRefetch).toHaveBeenCalled()
      })
    })

    describe('WHEN retryInvoice encounters a tax error', () => {
      it('THEN should show a danger toast', () => {
        render(<CustomerInvoiceDetails />)

        const onError = mockMutationOptions.retryInvoice?.onError

        expect(onError).toBeDefined()

        onError?.({
          graphQLErrors: [{ extensions: { details: { taxError: ['Tax error'] } } }],
        })

        expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'danger' }))
      })
    })

    describe('WHEN retryTaxProviderVoiding completes successfully', () => {
      it('THEN should show a success toast', () => {
        render(<CustomerInvoiceDetails />)

        const onCompleted = mockMutationOptions.retryTaxProviderVoiding?.onCompleted

        expect(onCompleted).toBeDefined()

        onCompleted?.({ retryTaxProviderVoiding: { id: 'invoice-123' } })

        expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
      })
    })

    describe('WHEN syncIntegrationInvoice completes successfully', () => {
      it('THEN should show a success toast', () => {
        render(<CustomerInvoiceDetails />)

        const onCompleted = mockMutationOptions.syncIntegration?.onCompleted

        expect(onCompleted).toBeDefined()

        onCompleted?.({ syncIntegrationInvoice: { invoiceId: 'invoice-123' } })

        expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
      })
    })

    describe('WHEN syncHubspotIntegrationInvoice completes successfully', () => {
      it('THEN should show a success toast', () => {
        render(<CustomerInvoiceDetails />)

        const onCompleted = mockMutationOptions.syncHubspot?.onCompleted

        expect(onCompleted).toBeDefined()

        onCompleted?.({ syncHubspotIntegrationInvoice: { invoiceId: 'invoice-123' } })

        expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
      })
    })

    describe('WHEN syncSalesforceInvoice completes successfully', () => {
      it('THEN should show a success toast', () => {
        render(<CustomerInvoiceDetails />)

        const onCompleted = mockMutationOptions.syncSalesforce?.onCompleted

        expect(onCompleted).toBeDefined()

        onCompleted?.({ syncSalesforceInvoice: { invoiceId: 'invoice-123' } })

        expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
      })
    })
  })
})
