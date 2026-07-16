import { renderHook } from '@testing-library/react'

import { LocalTaxProviderErrorsEnum } from '~/core/constants/form'
import {
  ErrorCodesEnum,
  InvoicePaymentStatusTypeEnum,
  InvoiceStatusTypeEnum,
  InvoiceTaxStatusTypeEnum,
  InvoiceTypeEnum,
  LagoApiError,
  ProviderTypeEnum,
} from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { useInvoiceAuthorizations } from '../useInvoiceAuthorizations'

// -- Mocks --

const mockActions = {
  canFinalize: jest.fn(),
  canDownload: jest.fn(),
  canIssueCreditNote: jest.fn(),
  canRecordPayment: jest.fn(),
  canGeneratePaymentUrl: jest.fn(),
  canUpdatePaymentStatus: jest.fn(),
  canSyncAccountingIntegration: jest.fn(),
  canSyncCRMIntegration: jest.fn(),
  canDispute: jest.fn(),
  canVoid: jest.fn(),
  canRegenerate: jest.fn(),
  canSyncTaxIntegration: jest.fn(),
  canResendEmail: jest.fn(),
  canRetryCollect: jest.fn(),
}

jest.mock('~/hooks/usePermissionsInvoiceActions', () => ({
  usePermissionsInvoiceActions: () => mockActions,
}))

let mockHasActiveWallet = false

jest.mock('~/hooks/customer/useCustomerHasActiveWallet', () => ({
  useCustomerHasActiveWallet: () => mockHasActiveWallet,
}))

// -- Helpers --

const createMockInvoice = (overrides: Record<string, unknown> = {}) =>
  ({
    id: 'invoice-id',
    status: InvoiceStatusTypeEnum.Finalized,
    taxStatus: InvoiceTaxStatusTypeEnum.Succeeded,
    paymentStatus: InvoicePaymentStatusTypeEnum.Pending,
    invoiceType: InvoiceTypeEnum.Subscription,
    errorDetails: [],
    taxProviderVoidable: false,
    paymentDisputeLostAt: null,
    integrationSyncable: false,
    integrationHubspotSyncable: false,
    regeneratedInvoiceId: null,
    billingEntity: { einvoicing: false },
    xmlUrl: null,
    totalDueAmountCents: '1000',
    totalPaidAmountCents: '0',
    totalAmountCents: '1000',
    ...overrides,
  }) as any

const createMockCustomer = (overrides: Record<string, unknown> = {}) =>
  ({
    id: 'customer-id',
    paymentProvider: ProviderTypeEnum.Stripe,
    ...overrides,
  }) as any

function prepare(
  params: {
    invoice?: any
    customer?: any
  } = {},
) {
  const invoiceParam = 'invoice' in params ? params.invoice : createMockInvoice()
  const customerParam = 'customer' in params ? params.customer : createMockCustomer()

  const wrapper = ({ children }: { children: React.ReactNode }) => AllTheProviders({ children })

  const { result } = renderHook(
    () =>
      useInvoiceAuthorizations({
        invoice: invoiceParam,
        customer: customerParam,
      }),
    { wrapper },
  )

  return { result }
}

// -- Tests --

describe('useInvoiceAuthorizations', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockHasActiveWallet = false
    // Default: all action permissions granted
    Object.values(mockActions).forEach((fn) => fn.mockReturnValue(true))
    // Default invoice is Finalized, so canFinalize should be false
    mockActions.canFinalize.mockReturnValue(false)
  })

  describe('when invoice is undefined', () => {
    it('should return safe defaults', () => {
      const { result } = prepare({ invoice: undefined })

      expect(result.current.hasTaxProviderError).toBe(false)
      expect(result.current.errorMessage).toBeUndefined()
      expect(result.current.canRecordPayment).toBe(false)
    })
  })

  describe('when invoice is null', () => {
    it('should return safe defaults', () => {
      const { result } = prepare({ invoice: null })

      expect(result.current.hasTaxProviderError).toBe(false)
      expect(result.current.errorMessage).toBeUndefined()
      expect(result.current.canRecordPayment).toBe(false)
    })
  })

  describe('hasTaxProviderError', () => {
    it('should be false when errorDetails is empty', () => {
      const { result } = prepare({
        invoice: createMockInvoice({ errorDetails: [] }),
      })

      expect(result.current.hasTaxProviderError).toBe(false)
    })

    it('should be true when errorDetails contains a TaxError', () => {
      const { result } = prepare({
        invoice: createMockInvoice({
          errorDetails: [
            {
              errorCode: ErrorCodesEnum.TaxError,
              errorDetails: LagoApiError.CurrencyCodeNotSupported,
            },
          ],
        }),
      })

      expect(result.current.hasTaxProviderError).toBe(true)
    })

    it('should be false when errorDetails contains only non-TaxError codes', () => {
      const { result } = prepare({
        invoice: createMockInvoice({
          errorDetails: [{ errorCode: ErrorCodesEnum.InvoiceGenerationError, errorDetails: null }],
        }),
      })

      expect(result.current.hasTaxProviderError).toBe(false)
    })
  })

  describe('errorMessage', () => {
    it('should be undefined when errorDetails is empty', () => {
      const { result } = prepare({
        invoice: createMockInvoice({ errorDetails: [] }),
      })

      expect(result.current.errorMessage).toBeUndefined()
    })

    it('should return CurrencyCodeNotSupported for CurrencyCodeNotSupported error', () => {
      const { result } = prepare({
        invoice: createMockInvoice({
          errorDetails: [
            {
              errorCode: ErrorCodesEnum.TaxError,
              errorDetails: LagoApiError.CurrencyCodeNotSupported,
            },
          ],
        }),
      })

      expect(result.current.errorMessage).toBe(LocalTaxProviderErrorsEnum.CurrencyCodeNotSupported)
    })

    it('should return CurrencyCodeNotSupported for InvalidEnumValue error', () => {
      const { result } = prepare({
        invoice: createMockInvoice({
          errorDetails: [
            {
              errorCode: ErrorCodesEnum.TaxError,
              errorDetails: LagoApiError.InvalidEnumValue,
            },
          ],
        }),
      })

      expect(result.current.errorMessage).toBe(LocalTaxProviderErrorsEnum.CurrencyCodeNotSupported)
    })

    it.each([
      LagoApiError.CustomerAddressCouldNotResolve,
      LagoApiError.CustomerAddressCountryNotSupported,
      LagoApiError.MissingAddress,
      LagoApiError.NotEnoughAddressesInfo,
      LagoApiError.InvalidAddress,
      LagoApiError.InvalidPostalCode,
      LagoApiError.AddressLocationNotFound,
    ])('should return CustomerAddressError for %s', (errorDetail) => {
      const { result } = prepare({
        invoice: createMockInvoice({
          errorDetails: [{ errorCode: ErrorCodesEnum.TaxError, errorDetails: errorDetail }],
        }),
      })

      expect(result.current.errorMessage).toBe(LocalTaxProviderErrorsEnum.CustomerAddressError)
    })

    it.each([
      LagoApiError.ProductExternalIdUnknown,
      LagoApiError.TaxCodeAssociatedWithItemCodeNotFound,
      LagoApiError.EntityNotFoundError,
    ])('should return ProductExternalIdUnknown for %s', (errorDetail) => {
      const { result } = prepare({
        invoice: createMockInvoice({
          errorDetails: [{ errorCode: ErrorCodesEnum.TaxError, errorDetails: errorDetail }],
        }),
      })

      expect(result.current.errorMessage).toBe(LocalTaxProviderErrorsEnum.ProductExternalIdUnknown)
    })

    it('should return GenericErrorMessage for unknown tax error details', () => {
      const { result } = prepare({
        invoice: createMockInvoice({
          errorDetails: [
            { errorCode: ErrorCodesEnum.TaxError, errorDetails: 'some_unknown_error' },
          ],
        }),
      })

      expect(result.current.errorMessage).toBe(LocalTaxProviderErrorsEnum.GenericErrorMessage)
    })

    it('should be undefined for non-tax error codes', () => {
      const { result } = prepare({
        invoice: createMockInvoice({
          errorDetails: [{ errorCode: ErrorCodesEnum.InvoiceGenerationError, errorDetails: null }],
        }),
      })

      expect(result.current.errorMessage).toBeUndefined()
    })
  })

  describe('authorizations', () => {
    describe('canRetryInvoice', () => {
      it('should be true when there is a tax provider error', () => {
        const { result } = prepare({
          invoice: createMockInvoice({
            errorDetails: [
              {
                errorCode: ErrorCodesEnum.TaxError,
                errorDetails: LagoApiError.CurrencyCodeNotSupported,
              },
            ],
          }),
        })

        expect(result.current.authorizations.canRetryInvoice).toBe(true)
      })

      it('should be false when there is no tax provider error', () => {
        const { result } = prepare()

        expect(result.current.authorizations.canRetryInvoice).toBe(false)
      })
    })

    describe('canFinalizeInvoice', () => {
      it('should be true when there is no tax error and canFinalize is true', () => {
        mockActions.canFinalize.mockReturnValue(true)

        const { result } = prepare({
          invoice: createMockInvoice({ status: InvoiceStatusTypeEnum.Draft }),
        })

        expect(result.current.authorizations.canFinalizeInvoice).toBe(true)
      })

      it('should be false when there is a tax error even if canFinalize is true', () => {
        mockActions.canFinalize.mockReturnValue(true)

        const { result } = prepare({
          invoice: createMockInvoice({
            status: InvoiceStatusTypeEnum.Draft,
            errorDetails: [
              {
                errorCode: ErrorCodesEnum.TaxError,
                errorDetails: LagoApiError.CurrencyCodeNotSupported,
              },
            ],
          }),
        })

        expect(result.current.authorizations.canFinalizeInvoice).toBe(false)
      })

      it('should be false when canFinalize is false', () => {
        mockActions.canFinalize.mockReturnValue(false)

        const { result } = prepare()

        expect(result.current.authorizations.canFinalizeInvoice).toBe(false)
      })
    })

    describe('canDownloadOnlyPdf', () => {
      it('should be true when no tax error, not finalizable, can download, and no XML', () => {
        mockActions.canFinalize.mockReturnValue(false)
        mockActions.canDownload.mockReturnValue(true)

        const { result } = prepare({
          invoice: createMockInvoice({
            billingEntity: { einvoicing: false },
            xmlUrl: null,
          }),
        })

        expect(result.current.authorizations.canDownloadOnlyPdf).toBe(true)
      })

      it('should be false when einvoicing is enabled', () => {
        mockActions.canFinalize.mockReturnValue(false)
        mockActions.canDownload.mockReturnValue(true)

        const { result } = prepare({
          invoice: createMockInvoice({
            billingEntity: { einvoicing: true },
          }),
        })

        expect(result.current.authorizations.canDownloadOnlyPdf).toBe(false)
      })

      it('should be false when xmlUrl is present', () => {
        mockActions.canFinalize.mockReturnValue(false)
        mockActions.canDownload.mockReturnValue(true)

        const { result } = prepare({
          invoice: createMockInvoice({
            xmlUrl: 'https://example.com/invoice.xml',
          }),
        })

        expect(result.current.authorizations.canDownloadOnlyPdf).toBe(false)
      })

      it('should be false when there is a tax error', () => {
        mockActions.canFinalize.mockReturnValue(false)
        mockActions.canDownload.mockReturnValue(true)

        const { result } = prepare({
          invoice: createMockInvoice({
            errorDetails: [
              {
                errorCode: ErrorCodesEnum.TaxError,
                errorDetails: LagoApiError.CurrencyCodeNotSupported,
              },
            ],
          }),
        })

        expect(result.current.authorizations.canDownloadOnlyPdf).toBe(false)
      })

      it('should be false when canDownload is false', () => {
        mockActions.canFinalize.mockReturnValue(false)
        mockActions.canDownload.mockReturnValue(false)

        const { result } = prepare()

        expect(result.current.authorizations.canDownloadOnlyPdf).toBe(false)
      })

      it('should be false when canFinalize is true (draft invoice)', () => {
        mockActions.canFinalize.mockReturnValue(true)
        mockActions.canDownload.mockReturnValue(true)

        const { result } = prepare()

        expect(result.current.authorizations.canDownloadOnlyPdf).toBe(false)
      })
    })

    describe('canDownloadPdfAndXml', () => {
      it('should be true when no tax error, not finalizable, can download, and einvoicing is enabled', () => {
        mockActions.canFinalize.mockReturnValue(false)
        mockActions.canDownload.mockReturnValue(true)

        const { result } = prepare({
          invoice: createMockInvoice({
            billingEntity: { einvoicing: true },
          }),
        })

        expect(result.current.authorizations.canDownloadPdfAndXml).toBe(true)
      })

      it('should be true when xmlUrl is present', () => {
        mockActions.canFinalize.mockReturnValue(false)
        mockActions.canDownload.mockReturnValue(true)

        const { result } = prepare({
          invoice: createMockInvoice({
            xmlUrl: 'https://example.com/invoice.xml',
          }),
        })

        expect(result.current.authorizations.canDownloadPdfAndXml).toBe(true)
      })

      it('should be false when no einvoicing and no xmlUrl', () => {
        mockActions.canFinalize.mockReturnValue(false)
        mockActions.canDownload.mockReturnValue(true)

        const { result } = prepare({
          invoice: createMockInvoice({
            billingEntity: { einvoicing: false },
            xmlUrl: null,
          }),
        })

        expect(result.current.authorizations.canDownloadPdfAndXml).toBe(false)
      })

      it('should be false when there is a tax error', () => {
        mockActions.canFinalize.mockReturnValue(false)
        mockActions.canDownload.mockReturnValue(true)

        const { result } = prepare({
          invoice: createMockInvoice({
            billingEntity: { einvoicing: true },
            errorDetails: [
              {
                errorCode: ErrorCodesEnum.TaxError,
                errorDetails: LagoApiError.CurrencyCodeNotSupported,
              },
            ],
          }),
        })

        expect(result.current.authorizations.canDownloadPdfAndXml).toBe(false)
      })
    })

    describe('delegated authorizations', () => {
      it('should pass status to canIssueCreditNote', () => {
        mockActions.canIssueCreditNote.mockReturnValue(true)

        const { result } = prepare()

        expect(result.current.authorizations.canIssueCreditNote).toBe(true)
        expect(mockActions.canIssueCreditNote).toHaveBeenCalledWith({
          status: InvoiceStatusTypeEnum.Finalized,
        })
      })

      it('should pass status, paymentStatus, and customer to canGeneratePaymentUrl', () => {
        mockActions.canGeneratePaymentUrl.mockReturnValue(true)
        const customer = createMockCustomer()

        const { result } = prepare({ customer })

        expect(result.current.authorizations.canGeneratePaymentUrl).toBe(true)
        expect(mockActions.canGeneratePaymentUrl).toHaveBeenCalledWith({
          status: InvoiceStatusTypeEnum.Finalized,
          paymentStatus: InvoicePaymentStatusTypeEnum.Pending,
          customer,
        })
      })

      it('should pass status and taxStatus to canUpdatePaymentStatus', () => {
        mockActions.canUpdatePaymentStatus.mockReturnValue(true)

        const { result } = prepare()

        expect(result.current.authorizations.canUpdatePaymentStatus).toBe(true)
        expect(mockActions.canUpdatePaymentStatus).toHaveBeenCalledWith({
          status: InvoiceStatusTypeEnum.Finalized,
          taxStatus: InvoiceTaxStatusTypeEnum.Succeeded,
        })
      })

      it('should pass integrationSyncable to canSyncAccountingIntegration', () => {
        mockActions.canSyncAccountingIntegration.mockReturnValue(true)

        const { result } = prepare({
          invoice: createMockInvoice({ integrationSyncable: true }),
        })

        expect(result.current.authorizations.canSyncAccountingIntegration).toBe(true)
        expect(mockActions.canSyncAccountingIntegration).toHaveBeenCalledWith({
          integrationSyncable: true,
        })
      })

      it('should pass integrationHubspotSyncable to canSyncCRMIntegration', () => {
        mockActions.canSyncCRMIntegration.mockReturnValue(true)

        const { result } = prepare({
          invoice: createMockInvoice({ integrationHubspotSyncable: true }),
        })

        expect(result.current.authorizations.canSyncCRMIntegration).toBe(true)
        expect(mockActions.canSyncCRMIntegration).toHaveBeenCalledWith({
          integrationHubspotSyncable: true,
        })
      })

      it('should pass status and paymentDisputeLostAt to canDispute', () => {
        mockActions.canDispute.mockReturnValue(true)

        const { result } = prepare()

        expect(result.current.authorizations.canDispute).toBe(true)
        expect(mockActions.canDispute).toHaveBeenCalledWith({
          status: InvoiceStatusTypeEnum.Finalized,
          paymentDisputeLostAt: null,
        })
      })

      it('should pass status to canVoid', () => {
        mockActions.canVoid.mockReturnValue(true)

        const { result } = prepare()

        expect(result.current.authorizations.canVoid).toBe(true)
        expect(mockActions.canVoid).toHaveBeenCalledWith({
          status: InvoiceStatusTypeEnum.Finalized,
        })
      })

      it('should pass taxProviderVoidable to canSyncTaxIntegration', () => {
        mockActions.canSyncTaxIntegration.mockReturnValue(true)

        const { result } = prepare({
          invoice: createMockInvoice({ taxProviderVoidable: true }),
        })

        expect(result.current.authorizations.canSyncTaxIntegration).toBe(true)
        expect(mockActions.canSyncTaxIntegration).toHaveBeenCalledWith({
          taxProviderVoidable: true,
        })
      })

      it('should pass status and billingEntity to canResendEmail', () => {
        mockActions.canResendEmail.mockReturnValue(true)

        const { result } = prepare()

        expect(result.current.authorizations.canResendEmail).toBe(true)
        expect(mockActions.canResendEmail).toHaveBeenCalledWith({
          status: InvoiceStatusTypeEnum.Finalized,
          billingEntity: { einvoicing: false },
        })
      })
    })

    describe('canResendEmail', () => {
      it('should be true when actions.canResendEmail returns true', () => {
        mockActions.canResendEmail.mockReturnValue(true)

        const { result } = prepare()

        expect(result.current.authorizations.canResendEmail).toBe(true)
      })

      it('should be false when actions.canResendEmail returns false', () => {
        mockActions.canResendEmail.mockReturnValue(false)

        const { result } = prepare()

        expect(result.current.authorizations.canResendEmail).toBe(false)
      })

      it('should pass billingEntity with emailSettings to canResendEmail', () => {
        mockActions.canResendEmail.mockReturnValue(true)

        const { result } = prepare({
          invoice: createMockInvoice({
            billingEntity: { einvoicing: false, emailSettings: ['invoice_finalized'] },
          }),
        })

        expect(result.current.authorizations.canResendEmail).toBe(true)
        expect(mockActions.canResendEmail).toHaveBeenCalledWith({
          status: InvoiceStatusTypeEnum.Finalized,
          billingEntity: { einvoicing: false, emailSettings: ['invoice_finalized'] },
        })
      })

      it('should pass billingEntity without emailSettings to canResendEmail', () => {
        mockActions.canResendEmail.mockReturnValue(false)

        const { result } = prepare({
          invoice: createMockInvoice({
            billingEntity: { einvoicing: false, emailSettings: [] },
          }),
        })

        expect(result.current.authorizations.canResendEmail).toBe(false)
        expect(mockActions.canResendEmail).toHaveBeenCalledWith({
          status: InvoiceStatusTypeEnum.Finalized,
          billingEntity: { einvoicing: false, emailSettings: [] },
        })
      })
    })

    describe('canRegenerate', () => {
      it('should pass hasActiveWallet=true to actions when customer has active wallet', () => {
        const customer = createMockCustomer()

        mockHasActiveWallet = true
        mockActions.canRegenerate.mockReturnValue(true)

        const { result } = prepare({
          invoice: createMockInvoice({
            status: InvoiceStatusTypeEnum.Voided,
            invoiceType: InvoiceTypeEnum.Credit,
          }),
        })

        expect(result.current.authorizations.canRegenerate).toBe(true)
        expect(mockActions.canRegenerate).toHaveBeenCalledWith(
          {
            customer,
            status: InvoiceStatusTypeEnum.Voided,
            regeneratedInvoiceId: null,
            invoiceType: InvoiceTypeEnum.Credit,
          },
          true,
        )
      })

      it('should pass hasActiveWallet=false to actions when customer has no active wallet', () => {
        mockHasActiveWallet = false
        mockActions.canRegenerate.mockReturnValue(false)

        const { result } = prepare({
          invoice: createMockInvoice({
            status: InvoiceStatusTypeEnum.Voided,
            invoiceType: InvoiceTypeEnum.Credit,
          }),
        })

        expect(result.current.authorizations.canRegenerate).toBe(false)
        expect(mockActions.canRegenerate).toHaveBeenCalledWith(
          expect.objectContaining({
            status: InvoiceStatusTypeEnum.Voided,
          }),
          false,
        )
      })
    })
  })

  describe('canRecordPayment', () => {
    it('should be true when invoice exists and actions.canRecordPayment returns true', () => {
      mockActions.canRecordPayment.mockReturnValue(true)

      const { result } = prepare()

      expect(result.current.canRecordPayment).toBe(true)
    })

    it('should be false when invoice is undefined', () => {
      const { result } = prepare({ invoice: undefined })

      expect(result.current.canRecordPayment).toBe(false)
    })

    it('should be false when invoice is null', () => {
      const { result } = prepare({ invoice: null })

      expect(result.current.canRecordPayment).toBe(false)
    })

    it('should be false when actions.canRecordPayment returns false', () => {
      mockActions.canRecordPayment.mockReturnValue(false)

      const { result } = prepare()

      expect(result.current.canRecordPayment).toBe(false)
    })
  })

  describe('hasActiveWallet', () => {
    it('should return true when customer has an active wallet', () => {
      mockHasActiveWallet = true

      const { result } = prepare()

      expect(result.current.hasActiveWallet).toBe(true)
    })

    it('should return false when customer has no active wallet', () => {
      mockHasActiveWallet = false

      const { result } = prepare()

      expect(result.current.hasActiveWallet).toBe(false)
    })
  })

  describe('integration', () => {
    it('should correctly combine all authorizations for a finalized invoice', () => {
      mockActions.canFinalize.mockReturnValue(false)
      mockActions.canDownload.mockReturnValue(true)
      mockActions.canIssueCreditNote.mockReturnValue(true)
      mockActions.canRecordPayment.mockReturnValue(true)
      mockActions.canGeneratePaymentUrl.mockReturnValue(true)
      mockActions.canUpdatePaymentStatus.mockReturnValue(true)
      mockActions.canSyncAccountingIntegration.mockReturnValue(true)
      mockActions.canSyncCRMIntegration.mockReturnValue(true)
      mockActions.canDispute.mockReturnValue(true)
      mockActions.canVoid.mockReturnValue(true)
      mockActions.canRegenerate.mockReturnValue(false)
      mockActions.canSyncTaxIntegration.mockReturnValue(false)
      mockActions.canResendEmail.mockReturnValue(true)

      const { result } = prepare({
        invoice: createMockInvoice({
          integrationSyncable: true,
          integrationHubspotSyncable: true,
        }),
      })

      expect(result.current.authorizations).toEqual({
        canRetryInvoice: false,
        canFinalizeInvoice: false,
        canDownloadOnlyPdf: true,
        canDownloadPdfAndXml: false,
        canIssueCreditNote: true,
        canRecordPayment: true,
        canGeneratePaymentUrl: true,
        canUpdatePaymentStatus: true,
        canSyncAccountingIntegration: true,
        canSyncCRMIntegration: true,
        canDispute: true,
        canVoid: true,
        canRegenerate: false,
        canSyncTaxIntegration: false,
        canResendEmail: true,
      })
    })

    it('should correctly handle an invoice with tax error', () => {
      mockActions.canFinalize.mockReturnValue(true)
      mockActions.canDownload.mockReturnValue(true)

      const { result } = prepare({
        invoice: createMockInvoice({
          status: InvoiceStatusTypeEnum.Draft,
          errorDetails: [
            {
              errorCode: ErrorCodesEnum.TaxError,
              errorDetails: LagoApiError.CustomerAddressCouldNotResolve,
            },
          ],
        }),
      })

      // Tax error overrides finalize and download
      expect(result.current.authorizations.canRetryInvoice).toBe(true)
      expect(result.current.authorizations.canFinalizeInvoice).toBe(false)
      expect(result.current.authorizations.canDownloadOnlyPdf).toBe(false)
      expect(result.current.authorizations.canDownloadPdfAndXml).toBe(false)
      expect(result.current.hasTaxProviderError).toBe(true)
      expect(result.current.errorMessage).toBe(LocalTaxProviderErrorsEnum.CustomerAddressError)
    })
  })
})
