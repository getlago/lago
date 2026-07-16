import { renderHook } from '@testing-library/react'

import { envGlobalVar } from '~/core/apolloClient'
import { AppEnvEnum } from '~/core/constants/globalTypes'
import {
  BillingEntityEmailSettingsEnum,
  GetCurrentUserInfosDocument,
  InvoicePaymentStatusTypeEnum,
  InvoiceStatusTypeEnum,
  InvoiceTaxStatusTypeEnum,
  InvoiceTypeEnum,
  ProviderTypeEnum,
} from '~/generated/graphql'
import { usePermissionsInvoiceActions } from '~/hooks/usePermissionsInvoiceActions'
import { AllTheProviders } from '~/test-utils'

// Mock the environment variables
jest.mock('~/core/apolloClient', () => ({
  envGlobalVar: jest.fn(() => ({
    disablePdfGeneration: false,
    appEnv: 'qa',
    apiUrl: 'test',
    lagoOauthProxyUrl: 'test',
    disableSignUp: false,
    appVersion: 'test',
    sentryDsn: 'test',
    nangoPublicKey: 'test',
  })),
  initializeTranslations: jest.fn(),
}))

// Default permissions for convenience
const DEFAULT_PERMISSIONS = {
  invoicesView: true,
  invoicesUpdate: true,
  draftInvoicesUpdate: true,
  invoicesSend: true,
  invoicesVoid: true,
  creditNotesCreate: true,
  paymentsCreate: true,
}

const mockCurrentUser = {
  currentMembership: {
    id: '2',
    organization: {
      id: '3',
      name: 'Organization',
      logoUrl: 'https://logo.com',
    },
    permissions: DEFAULT_PERMISSIONS,
  },
}

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => mockCurrentUser,
}))

const mockedEnvGlobalVar = envGlobalVar as jest.MockedFunction<typeof envGlobalVar>

async function prepare(permissions: Partial<typeof DEFAULT_PERMISSIONS> = DEFAULT_PERMISSIONS) {
  // Create membership with specified permissions
  const membership = {
    id: '2',
    organization: {
      id: '3',
      name: 'Organization',
      logoUrl: 'https://logo.com',
    },
    permissions: {
      ...DEFAULT_PERMISSIONS,
      ...permissions,
    },
  }

  // Update the mock current user
  mockCurrentUser.currentMembership = membership

  const mocks = [
    {
      request: {
        query: GetCurrentUserInfosDocument,
      },
      result: {
        data: {
          currentUser: {
            id: '1',
            email: 'gavin@hooli.com',
            premium: true,
            memberships: [membership],
            __typename: 'User',
          },
        },
      },
    },
  ]

  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({
      children,
      mocks,
      forceTypenames: true,
    })

  const { result } = renderHook(() => usePermissionsInvoiceActions(), {
    wrapper: customWrapper,
  })

  return { result }
}

describe('usePermissionsInvoiceActions', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    // Default mock values
    mockedEnvGlobalVar.mockReturnValue({
      disablePdfGeneration: false,
      appEnv: AppEnvEnum.qa,
      apiUrl: 'test',
      lagoOauthProxyUrl: 'test',
      disableSignUp: false,
      appVersion: 'test',
      sentryDsn: 'test',
      nangoPublicKey: 'test',
      lagoSupersetUrl: '',
    })
  })

  describe('canDownload', () => {
    it('should return true when invoice is finalized, tax status is not pending, has permissions, and PDF generation is enabled', async () => {
      const { result } = await prepare() // Uses default permissions (all true)

      expect(
        result.current.canDownload({
          status: InvoiceStatusTypeEnum.Finalized,
          taxStatus: InvoiceTaxStatusTypeEnum.Succeeded,
        }),
      ).toBe(true)
    })

    it('should return false when invoice status is Draft', async () => {
      const { result } = await prepare() // Uses default permissions

      expect(
        result.current.canDownload({
          status: InvoiceStatusTypeEnum.Draft,
          taxStatus: InvoiceTaxStatusTypeEnum.Succeeded,
        }),
      ).toBe(false)
    })

    it('should return false when invoice status is Failed', async () => {
      const { result } = await prepare()

      expect(
        result.current.canDownload({
          status: InvoiceStatusTypeEnum.Failed,
          taxStatus: InvoiceTaxStatusTypeEnum.Succeeded,
        }),
      ).toBe(false)
    })

    it('should return false when invoice status is Pending', async () => {
      const { result } = await prepare()

      expect(
        result.current.canDownload({
          status: InvoiceStatusTypeEnum.Pending,
          taxStatus: InvoiceTaxStatusTypeEnum.Succeeded,
        }),
      ).toBe(false)
    })

    it('should return false when tax status is Pending', async () => {
      const { result } = await prepare()

      expect(
        result.current.canDownload({
          status: InvoiceStatusTypeEnum.Finalized,
          taxStatus: InvoiceTaxStatusTypeEnum.Pending,
        }),
      ).toBe(false)
    })

    it('should return false when user does not have invoicesView permission', async () => {
      const { result } = await prepare({ invoicesView: false }) // Only disable this specific permission

      expect(
        result.current.canDownload({
          status: InvoiceStatusTypeEnum.Finalized,
          taxStatus: InvoiceTaxStatusTypeEnum.Succeeded,
        }),
      ).toBe(false)
    })

    it('should return false when PDF generation is disabled', async () => {
      // Mock PDF generation disabled first
      mockedEnvGlobalVar.mockReturnValue({
        disablePdfGeneration: true,
        appEnv: AppEnvEnum.qa,
        apiUrl: 'test',
        lagoOauthProxyUrl: 'test',
        disableSignUp: false,
        appVersion: 'test',
        sentryDsn: 'test',
        nangoPublicKey: 'test',
        lagoSupersetUrl: '',
      })

      // Create a new hook instance that will use the updated mock
      const { result } = renderHook(() => usePermissionsInvoiceActions(), {
        wrapper: ({ children }: { children: React.ReactNode }) => AllTheProviders({ children }),
      })

      expect(
        result.current.canDownload({
          status: InvoiceStatusTypeEnum.Finalized,
          taxStatus: InvoiceTaxStatusTypeEnum.Succeeded,
        }),
      ).toBe(false)
    })

    it('should return true for voided invoice with valid tax status', async () => {
      const { result } = await prepare()

      expect(
        result.current.canDownload({
          status: InvoiceStatusTypeEnum.Voided,
          taxStatus: InvoiceTaxStatusTypeEnum.Succeeded,
        }),
      ).toBe(true)
    })
  })

  describe('canFinalize', () => {
    it('should return true when invoice is draft and user has permission', async () => {
      const { result } = await prepare()

      expect(result.current.canFinalize({ status: InvoiceStatusTypeEnum.Draft })).toBe(true)
    })

    it('should return false when invoice is Failed', async () => {
      const { result } = await prepare()

      expect(result.current.canFinalize({ status: InvoiceStatusTypeEnum.Failed })).toBe(false)
    })

    it('should return false when invoice is Pending', async () => {
      const { result } = await prepare()

      expect(result.current.canFinalize({ status: InvoiceStatusTypeEnum.Pending })).toBe(false)
    })

    it('should return false when invoice is already Finalized', async () => {
      const { result } = await prepare()

      expect(result.current.canFinalize({ status: InvoiceStatusTypeEnum.Finalized })).toBe(false)
    })

    it('should return false when user does not have invoicesUpdate permission', async () => {
      const { result } = await prepare({ invoicesUpdate: false })

      expect(result.current.canFinalize({ status: InvoiceStatusTypeEnum.Draft })).toBe(false)
    })

    it('should return false when user has draftInvoicesUpdate but not invoicesUpdate', async () => {
      const { result } = await prepare({
        invoicesUpdate: false,
        draftInvoicesUpdate: true,
      })

      expect(result.current.canFinalize({ status: InvoiceStatusTypeEnum.Draft })).toBe(false)
    })

    it('should return true when user has both invoicesUpdate and draftInvoicesUpdate permissions', async () => {
      const { result } = await prepare({
        invoicesUpdate: true,
        draftInvoicesUpdate: true,
      })

      expect(result.current.canFinalize({ status: InvoiceStatusTypeEnum.Draft })).toBe(true)
    })

    it('should return false for voided invoice', async () => {
      const { result } = await prepare()

      expect(result.current.canFinalize({ status: InvoiceStatusTypeEnum.Voided })).toBe(false)
    })
  })

  describe('canGeneratePaymentUrl', () => {
    it('should return true when all conditions are met', async () => {
      const { result } = await prepare()

      expect(
        result.current.canGeneratePaymentUrl({
          status: InvoiceStatusTypeEnum.Finalized,
          paymentStatus: InvoicePaymentStatusTypeEnum.Pending,
          customer: { paymentProvider: ProviderTypeEnum.Stripe },
        }),
      ).toBe(true)
    })

    it('should return false when customer has no payment provider', async () => {
      const { result } = await prepare()

      expect(
        result.current.canGeneratePaymentUrl({
          status: InvoiceStatusTypeEnum.Finalized,
          paymentStatus: InvoicePaymentStatusTypeEnum.Pending,
          customer: { paymentProvider: null },
        }),
      ).toBe(false)
    })

    it('should return false when invoice is not finalized', async () => {
      const { result } = await prepare()

      expect(
        result.current.canGeneratePaymentUrl({
          status: InvoiceStatusTypeEnum.Draft,
          paymentStatus: InvoicePaymentStatusTypeEnum.Pending,
          customer: { paymentProvider: ProviderTypeEnum.Stripe },
        }),
      ).toBe(false)
    })

    it('should return false when payment is already succeeded', async () => {
      const { result } = await prepare()

      expect(
        result.current.canGeneratePaymentUrl({
          status: InvoiceStatusTypeEnum.Finalized,
          paymentStatus: InvoicePaymentStatusTypeEnum.Succeeded,
          customer: { paymentProvider: ProviderTypeEnum.Stripe },
        }),
      ).toBe(false)
    })

    it('should return true when payment status is failed', async () => {
      const { result } = await prepare()

      expect(
        result.current.canGeneratePaymentUrl({
          status: InvoiceStatusTypeEnum.Finalized,
          paymentStatus: InvoicePaymentStatusTypeEnum.Failed,
          customer: { paymentProvider: ProviderTypeEnum.Stripe },
        }),
      ).toBe(true)
    })
  })

  describe('canRetryCollect', () => {
    it('should return true when invoice is finalized, payment failed, and has permission', async () => {
      const { result } = await prepare()

      expect(
        result.current.canRetryCollect({
          status: InvoiceStatusTypeEnum.Finalized,
          paymentStatus: InvoicePaymentStatusTypeEnum.Failed,
        }),
      ).toBe(true)
    })

    it('should return true when invoice is finalized, payment pending, and has permission', async () => {
      const { result } = await prepare()

      expect(
        result.current.canRetryCollect({
          status: InvoiceStatusTypeEnum.Finalized,
          paymentStatus: InvoicePaymentStatusTypeEnum.Pending,
        }),
      ).toBe(true)
    })

    it('should return false when invoice is not finalized', async () => {
      const { result } = await prepare()

      expect(
        result.current.canRetryCollect({
          status: InvoiceStatusTypeEnum.Draft,
          paymentStatus: InvoicePaymentStatusTypeEnum.Failed,
        }),
      ).toBe(false)
    })

    it('should return false when payment succeeded', async () => {
      const { result } = await prepare()

      expect(
        result.current.canRetryCollect({
          status: InvoiceStatusTypeEnum.Finalized,
          paymentStatus: InvoicePaymentStatusTypeEnum.Succeeded,
        }),
      ).toBe(false)
    })

    it('should return false when user does not have invoicesSend permission', async () => {
      const { result } = await prepare({ invoicesSend: false })

      expect(
        result.current.canRetryCollect({
          status: InvoiceStatusTypeEnum.Finalized,
          paymentStatus: InvoicePaymentStatusTypeEnum.Failed,
        }),
      ).toBe(false)
    })
  })

  describe('canUpdatePaymentStatus', () => {
    it('should return true when invoice is finalized, tax status is not pending, and has permission', async () => {
      const { result } = await prepare()

      expect(
        result.current.canUpdatePaymentStatus({
          status: InvoiceStatusTypeEnum.Finalized,
          taxStatus: InvoiceTaxStatusTypeEnum.Succeeded,
        }),
      ).toBe(true)
    })

    it('should return false when invoice status is Draft', async () => {
      const { result } = await prepare()

      expect(
        result.current.canUpdatePaymentStatus({
          status: InvoiceStatusTypeEnum.Draft,
          taxStatus: InvoiceTaxStatusTypeEnum.Succeeded,
        }),
      ).toBe(false)
    })

    it('should return false when invoice status is Voided', async () => {
      const { result } = await prepare()

      expect(
        result.current.canUpdatePaymentStatus({
          status: InvoiceStatusTypeEnum.Voided,
          taxStatus: InvoiceTaxStatusTypeEnum.Succeeded,
        }),
      ).toBe(false)
    })

    it('should return false when invoice status is Failed', async () => {
      const { result } = await prepare()

      expect(
        result.current.canUpdatePaymentStatus({
          status: InvoiceStatusTypeEnum.Failed,
          taxStatus: InvoiceTaxStatusTypeEnum.Succeeded,
        }),
      ).toBe(false)
    })

    it('should return false when invoice status is Pending', async () => {
      const { result } = await prepare()

      expect(
        result.current.canUpdatePaymentStatus({
          status: InvoiceStatusTypeEnum.Pending,
          taxStatus: InvoiceTaxStatusTypeEnum.Succeeded,
        }),
      ).toBe(false)
    })

    it('should return false when tax status is Pending', async () => {
      const { result } = await prepare()

      expect(
        result.current.canUpdatePaymentStatus({
          status: InvoiceStatusTypeEnum.Finalized,
          taxStatus: InvoiceTaxStatusTypeEnum.Pending,
        }),
      ).toBe(false)
    })

    it('should return false when user does not have invoicesUpdate permission', async () => {
      const { result } = await prepare({ invoicesUpdate: false })

      expect(
        result.current.canUpdatePaymentStatus({
          status: InvoiceStatusTypeEnum.Finalized,
          taxStatus: InvoiceTaxStatusTypeEnum.Succeeded,
        }),
      ).toBe(false)
    })
  })

  describe('canVoid', () => {
    it('should return true when invoice is finalized and has permission', async () => {
      const { result } = await prepare()

      expect(result.current.canVoid({ status: InvoiceStatusTypeEnum.Finalized })).toBe(true)
    })

    it('should return false when invoice is not finalized', async () => {
      const { result } = await prepare()

      expect(result.current.canVoid({ status: InvoiceStatusTypeEnum.Draft })).toBe(false)
    })

    it('should return false when invoice is voided', async () => {
      const { result } = await prepare()

      expect(result.current.canVoid({ status: InvoiceStatusTypeEnum.Voided })).toBe(false)
    })

    it('should return false when user does not have invoicesVoid permission', async () => {
      const { result } = await prepare({ invoicesVoid: false })

      expect(result.current.canVoid({ status: InvoiceStatusTypeEnum.Finalized })).toBe(false)
    })
  })

  describe('canRegenerate', () => {
    it('should return true for regular invoice when voided, not regenerated, and has permission', async () => {
      const { result } = await prepare()

      expect(
        result.current.canRegenerate(
          {
            status: InvoiceStatusTypeEnum.Voided,
            regeneratedInvoiceId: null,
            invoiceType: InvoiceTypeEnum.Subscription,
          },
          false,
        ),
      ).toBe(true)
    })

    it('should return true for prepaid credit invoice when voided, not regenerated, has permission, and has active wallet', async () => {
      const { result } = await prepare()

      expect(
        result.current.canRegenerate(
          {
            status: InvoiceStatusTypeEnum.Voided,
            regeneratedInvoiceId: null,
            invoiceType: InvoiceTypeEnum.Credit,
          },
          true,
        ),
      ).toBe(true)
    })

    it('should return false for prepaid credit invoice when no active wallet', async () => {
      const { result } = await prepare()

      expect(
        result.current.canRegenerate(
          {
            status: InvoiceStatusTypeEnum.Voided,
            regeneratedInvoiceId: null,
            invoiceType: InvoiceTypeEnum.Credit,
          },
          false,
        ),
      ).toBe(false)
    })

    it('should return false when invoice is not voided', async () => {
      const { result } = await prepare()

      expect(
        result.current.canRegenerate(
          {
            status: InvoiceStatusTypeEnum.Finalized,
            regeneratedInvoiceId: null,
            invoiceType: InvoiceTypeEnum.Subscription,
          },
          false,
        ),
      ).toBe(false)
    })

    it('should return false when invoice is already regenerated', async () => {
      const { result } = await prepare()

      expect(
        result.current.canRegenerate(
          {
            status: InvoiceStatusTypeEnum.Voided,
            regeneratedInvoiceId: 'regenerated-id',
            invoiceType: InvoiceTypeEnum.Subscription,
          },
          false,
        ),
      ).toBe(false)
    })

    it('should return false when user does not have invoicesVoid permission', async () => {
      const { result } = await prepare({ invoicesVoid: false })

      expect(
        result.current.canRegenerate(
          {
            status: InvoiceStatusTypeEnum.Voided,
            regeneratedInvoiceId: null,
            invoiceType: InvoiceTypeEnum.Subscription,
          },
          false,
        ),
      ).toBe(false)
    })

    it('should return false if the invoice has a deleted customer', async () => {
      const { result } = await prepare()

      expect(
        result.current.canRegenerate(
          {
            status: InvoiceStatusTypeEnum.Voided,
            regeneratedInvoiceId: null,
            invoiceType: InvoiceTypeEnum.Subscription,
            customer: {
              deletedAt: '2026',
            },
          },
          false,
        ),
      ).toBe(false)
    })
  })

  describe('canIssueCreditNote', () => {
    it('should return true when invoice is finalized and has permission', async () => {
      const { result } = await prepare()

      expect(result.current.canIssueCreditNote({ status: InvoiceStatusTypeEnum.Finalized })).toBe(
        true,
      )
    })

    it('should return false when invoice is not finalized', async () => {
      const { result } = await prepare()

      expect(result.current.canIssueCreditNote({ status: InvoiceStatusTypeEnum.Draft })).toBe(false)
    })

    it('should return false when invoice is voided', async () => {
      const { result } = await prepare()

      expect(result.current.canIssueCreditNote({ status: InvoiceStatusTypeEnum.Voided })).toBe(
        false,
      )
    })

    it('should return false when user does not have creditNotesCreate permission', async () => {
      const { result } = await prepare({ creditNotesCreate: false })

      expect(result.current.canIssueCreditNote({ status: InvoiceStatusTypeEnum.Finalized })).toBe(
        false,
      )
    })
  })

  describe('canRecordPayment', () => {
    it('should return true when invoice is finalized, has due amount, and has permission', async () => {
      const { result } = await prepare()

      expect(
        result.current.canRecordPayment({
          status: InvoiceStatusTypeEnum.Finalized,
          totalDueAmountCents: '1000',
          totalPaidAmountCents: '500',
          totalAmountCents: '1500',
        }),
      ).toBe(true)
    })

    it('should return false when invoice is not finalized', async () => {
      const { result } = await prepare()

      expect(
        result.current.canRecordPayment({
          status: InvoiceStatusTypeEnum.Draft,
          totalDueAmountCents: '1000',
          totalPaidAmountCents: '500',
          totalAmountCents: '1500',
        }),
      ).toBe(false)
    })

    it('should return false when no due amount', async () => {
      const { result } = await prepare()

      expect(
        result.current.canRecordPayment({
          status: InvoiceStatusTypeEnum.Finalized,
          totalDueAmountCents: '0',
          totalPaidAmountCents: '1500',
          totalAmountCents: '1500',
        }),
      ).toBe(false)
    })

    it('should return false when fully paid', async () => {
      const { result } = await prepare()

      expect(
        result.current.canRecordPayment({
          status: InvoiceStatusTypeEnum.Finalized,
          totalDueAmountCents: '1000',
          totalPaidAmountCents: '1500',
          totalAmountCents: '1500',
        }),
      ).toBe(false)
    })

    it('should return false when user does not have paymentsCreate permission', async () => {
      const { result } = await prepare({ paymentsCreate: false })

      expect(
        result.current.canRecordPayment({
          status: InvoiceStatusTypeEnum.Finalized,
          totalDueAmountCents: '1000',
          totalPaidAmountCents: '500',
          totalAmountCents: '1500',
        }),
      ).toBe(false)
    })
  })

  describe('canDispute', () => {
    it('should return true when invoice is finalized, not disputed, and has permission', async () => {
      const { result } = await prepare()

      expect(
        result.current.canDispute({
          status: InvoiceStatusTypeEnum.Finalized,
          paymentDisputeLostAt: null,
        }),
      ).toBe(true)
    })

    it('should return false when invoice is not finalized', async () => {
      const { result } = await prepare()

      expect(
        result.current.canDispute({
          status: InvoiceStatusTypeEnum.Draft,
          paymentDisputeLostAt: null,
        }),
      ).toBe(false)
    })

    it('should return false when payment dispute is already lost', async () => {
      const { result } = await prepare()

      expect(
        result.current.canDispute({
          status: InvoiceStatusTypeEnum.Finalized,
          paymentDisputeLostAt: '2023-01-01T00:00:00Z',
        }),
      ).toBe(false)
    })

    it('should return false when user does not have invoicesUpdate permission', async () => {
      const { result } = await prepare({ invoicesUpdate: false })

      expect(
        result.current.canDispute({
          status: InvoiceStatusTypeEnum.Finalized,
          paymentDisputeLostAt: null,
        }),
      ).toBe(false)
    })
  })

  describe('canSyncAccountingIntegration', () => {
    it('should return true when invoice is syncable', async () => {
      const { result } = await prepare()

      expect(result.current.canSyncAccountingIntegration({ integrationSyncable: true })).toBe(true)
    })

    it('should return false when invoice is not syncable', async () => {
      const { result } = await prepare()

      expect(result.current.canSyncAccountingIntegration({ integrationSyncable: false })).toBe(
        false,
      )
    })
  })

  describe('canSyncCRMIntegration', () => {
    it('should return true when invoice is HubSpot syncable', async () => {
      const { result } = await prepare()

      expect(result.current.canSyncCRMIntegration({ integrationHubspotSyncable: true })).toBe(true)
    })

    it('should return false when invoice is not HubSpot syncable', async () => {
      const { result } = await prepare()

      expect(result.current.canSyncCRMIntegration({ integrationHubspotSyncable: false })).toBe(
        false,
      )
    })
  })

  describe('canSyncTaxIntegration', () => {
    it('should return true when invoice is tax provider voidable', async () => {
      const { result } = await prepare()

      expect(result.current.canSyncTaxIntegration({ taxProviderVoidable: true })).toBe(true)
    })

    it('should return false when invoice is not tax provider voidable', async () => {
      const { result } = await prepare()

      expect(result.current.canSyncTaxIntegration({ taxProviderVoidable: false })).toBe(false)
    })
  })

  describe('canResendEmail', () => {
    const billingEntityWithEmailSettings = {
      id: '1',
      name: 'Test',
      code: 'test',
      emailSettings: [BillingEntityEmailSettingsEnum.InvoiceFinalized],
    }

    const billingEntityWithoutEmailSettings = {
      id: '1',
      name: 'Test',
      code: 'test',
      emailSettings: [] as BillingEntityEmailSettingsEnum[],
    }

    it('should return true when invoice is finalized, has invoicesSend permission, and email scenario is active', async () => {
      const { result } = await prepare()

      expect(
        result.current.canResendEmail({
          status: InvoiceStatusTypeEnum.Finalized,
          billingEntity: billingEntityWithEmailSettings,
        }),
      ).toBe(true)
    })

    it('should return false when invoice is not finalized', async () => {
      const { result } = await prepare()

      expect(
        result.current.canResendEmail({
          status: InvoiceStatusTypeEnum.Draft,
          billingEntity: billingEntityWithEmailSettings,
        }),
      ).toBe(false)
    })

    it('should return false when invoice is voided', async () => {
      const { result } = await prepare()

      expect(
        result.current.canResendEmail({
          status: InvoiceStatusTypeEnum.Voided,
          billingEntity: billingEntityWithEmailSettings,
        }),
      ).toBe(false)
    })

    it('should return false when invoice is pending', async () => {
      const { result } = await prepare()

      expect(
        result.current.canResendEmail({
          status: InvoiceStatusTypeEnum.Pending,
          billingEntity: billingEntityWithEmailSettings,
        }),
      ).toBe(false)
    })

    it('should return false when invoice is failed', async () => {
      const { result } = await prepare()

      expect(
        result.current.canResendEmail({
          status: InvoiceStatusTypeEnum.Failed,
          billingEntity: billingEntityWithEmailSettings,
        }),
      ).toBe(false)
    })

    it('should return false when user does not have invoicesSend permission', async () => {
      const { result } = await prepare({ invoicesSend: false })

      expect(
        result.current.canResendEmail({
          status: InvoiceStatusTypeEnum.Finalized,
          billingEntity: billingEntityWithEmailSettings,
        }),
      ).toBe(false)
    })

    it('should return false when email scenario is inactive', async () => {
      const { result } = await prepare()

      expect(
        result.current.canResendEmail({
          status: InvoiceStatusTypeEnum.Finalized,
          billingEntity: billingEntityWithoutEmailSettings,
        }),
      ).toBe(false)
    })
  })

  describe('integration tests', () => {
    it('should return all expected methods from the hook', async () => {
      const { result } = await prepare()

      expect(typeof result.current.canDownload).toBe('function')
      expect(typeof result.current.canFinalize).toBe('function')
      expect(typeof result.current.canRetryCollect).toBe('function')
      expect(typeof result.current.canGeneratePaymentUrl).toBe('function')
      expect(typeof result.current.canUpdatePaymentStatus).toBe('function')
      expect(typeof result.current.canVoid).toBe('function')
      expect(typeof result.current.canRegenerate).toBe('function')
      expect(typeof result.current.canIssueCreditNote).toBe('function')
      expect(typeof result.current.canRecordPayment).toBe('function')
      expect(typeof result.current.canDispute).toBe('function')
      expect(typeof result.current.canSyncAccountingIntegration).toBe('function')
      expect(typeof result.current.canSyncCRMIntegration).toBe('function')
      expect(typeof result.current.canSyncTaxIntegration).toBe('function')
      expect(typeof result.current.canResendEmail).toBe('function')
    })

    it('should handle complex invoice scenarios correctly', async () => {
      const { result } = await prepare()

      const complexInvoice = {
        status: InvoiceStatusTypeEnum.Finalized,
        taxStatus: InvoiceTaxStatusTypeEnum.Succeeded,
        paymentStatus: InvoicePaymentStatusTypeEnum.Failed,
        totalDueAmountCents: '1000',
        totalPaidAmountCents: '0',
        totalAmountCents: '1000',
        paymentDisputeLostAt: null,
        regeneratedInvoiceId: null,
        invoiceType: InvoiceTypeEnum.Subscription,
        integrationSyncable: true,
        integrationHubspotSyncable: true,
        taxProviderVoidable: true,
        customer: { paymentProvider: ProviderTypeEnum.Stripe, deletedAt: '' },
      }

      expect(result.current.canDownload(complexInvoice)).toBe(true)
      expect(result.current.canFinalize(complexInvoice)).toBe(false) // Already finalized
      expect(result.current.canRetryCollect(complexInvoice)).toBe(true)
      expect(result.current.canGeneratePaymentUrl(complexInvoice)).toBe(true)
      expect(result.current.canUpdatePaymentStatus(complexInvoice)).toBe(true)
      expect(result.current.canVoid(complexInvoice)).toBe(true)
      expect(result.current.canRegenerate(complexInvoice, false)).toBe(false) // Not voided
      expect(result.current.canIssueCreditNote(complexInvoice)).toBe(true)
      expect(result.current.canRecordPayment(complexInvoice)).toBe(true)
      expect(result.current.canDispute(complexInvoice)).toBe(true)
      expect(result.current.canSyncAccountingIntegration(complexInvoice)).toBe(true)
      expect(result.current.canSyncCRMIntegration(complexInvoice)).toBe(true)
      expect(result.current.canSyncTaxIntegration(complexInvoice)).toBe(true)
    })
  })
})
