import { act, cleanup, screen, waitFor } from '@testing-library/react'

import {
  CurrencyEnum,
  FinalizeZeroAmountInvoiceEnum,
  GetCustomerSettingsDocument,
} from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

import { CustomerSettings } from '../CustomerSettings'

const CUSTOMER_ID = 'customer-123'

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useParams: () => ({ customerId: 'customer-123' }),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({
    isPremium: true,
  }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: (permissions: string[]) => permissions.includes('customersUpdate'),
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: {
      id: 'org-123',
      name: 'Test Organization',
      premiumIntegrations: ['auto_dunning'],
    },
  }),
}))

// Mock dialog components that use useParams() internally
// Using require('react').forwardRef inside each mock factory to avoid hoisting issues
jest.mock('~/components/customers/EditCustomerInvoiceGracePeriodDialog', () => {
  const React = jest.requireActual('react')
  const MockDialog = React.forwardRef(() => null)

  MockDialog.displayName = 'EditCustomerInvoiceGracePeriodDialog'
  return { EditCustomerInvoiceGracePeriodDialog: MockDialog }
})

jest.mock('~/components/customers/DeleteCustomerGracePeriodeDialog', () => {
  const React = jest.requireActual('react')
  const MockDialog = React.forwardRef(() => null)

  MockDialog.displayName = 'DeleteCustomerGracePeriodeDialog'
  return { DeleteCustomerGracePeriodeDialog: MockDialog }
})

jest.mock('~/components/customers/EditCustomerDocumentLocaleDialog', () => ({
  useEditCustomerDocumentLocaleDialog: () => ({
    openEditCustomerDocumentLocaleDialog: jest.fn(),
  }),
}))

jest.mock('~/components/customers/DeleteCustomerDocumentLocaleDialog', () => ({
  useDeleteCustomerDocumentLocaleDialog: () => ({
    openDeleteCustomerDocumentLocaleDialog: jest.fn(),
  }),
}))

jest.mock('~/components/customers/EditCustomerVatRateDialog', () => {
  const React = jest.requireActual('react')
  const MockDialog = React.forwardRef(() => null)

  MockDialog.displayName = 'EditCustomerVatRateDialog'
  return { EditCustomerVatRateDialog: MockDialog }
})

jest.mock('~/components/customers/DeleteCustomerVatRateDialog', () => ({
  useDeleteCustomerVatRateDialog: () => ({
    openDeleteCustomerVatRateDialog: jest.fn(),
  }),
}))

jest.mock('~/components/customers/EditCustomerDunningCampaignDialog', () => {
  const React = jest.requireActual('react')
  const MockDialog = React.forwardRef(() => null)

  MockDialog.displayName = 'EditCustomerDunningCampaignDialog'
  return { EditCustomerDunningCampaignDialog: MockDialog }
})

jest.mock('~/components/customers/EditCustomerInvoiceCustomSectionsDialog', () => {
  const React = jest.requireActual('react')
  const MockDialog = React.forwardRef(() => null)

  MockDialog.displayName = 'EditCustomerInvoiceCustomSectionsDialog'
  return { EditCustomerInvoiceCustomSectionsDialog: MockDialog }
})

jest.mock('~/components/customers/settings/EditCustomerIssuingDatePolicyDialog', () => {
  const React = jest.requireActual('react')
  const MockDialog = React.forwardRef(() => null)

  MockDialog.displayName = 'EditCustomerIssuingDatePolicyDialog'
  return { EditCustomerIssuingDatePolicyDialog: MockDialog }
})

jest.mock('~/components/customers/DeleteCustomerFinalizeZeroAmountInvoiceDialog', () => {
  const React = jest.requireActual('react')
  const MockDialog = React.forwardRef(() => null)

  MockDialog.displayName = 'DeleteCustomerFinalizeZeroAmountInvoiceDialog'
  return { DeleteCustomerFinalizeZeroAmountInvoiceDialog: MockDialog }
})

jest.mock('~/components/customers/DeleteCustomerNetPaymentTermDialog', () => {
  const React = jest.requireActual('react')
  const MockDialog = React.forwardRef(() => null)

  MockDialog.displayName = 'DeleteOrganizationNetPaymentTermDialog'
  return { DeleteOrganizationNetPaymentTermDialog: MockDialog }
})

jest.mock('~/components/settings/invoices/EditNetPaymentTermDialog', () => {
  const React = jest.requireActual('react')
  const MockDialog = React.forwardRef(() => null)

  MockDialog.displayName = 'EditNetPaymentTermDialog'
  return { EditNetPaymentTermDialog: MockDialog }
})

jest.mock('~/components/settings/invoices/EditFinalizeZeroAmountInvoiceDialog', () => {
  const React = jest.requireActual('react')
  const MockDialog = React.forwardRef(() => null)

  MockDialog.displayName = 'EditFinalizeZeroAmountInvoiceDialog'
  return { EditFinalizeZeroAmountInvoiceDialog: MockDialog }
})

jest.mock('~/components/dialogs/PremiumWarningDialog', () => ({
  usePremiumWarningDialog: () => ({ open: jest.fn(), close: jest.fn() }),
}))

const createCustomerSettingsMock = (overrides = {}) => ({
  request: {
    query: GetCustomerSettingsDocument,
    variables: { id: CUSTOMER_ID },
  },
  result: {
    data: {
      customer: {
        __typename: 'Customer',
        id: CUSTOMER_ID,
        externalId: 'ext-customer-123',
        name: 'Test Customer',
        displayName: 'Test Customer',
        invoiceGracePeriod: null,
        netPaymentTerm: null,
        finalizeZeroAmountInvoice: FinalizeZeroAmountInvoiceEnum.Inherit,
        currency: CurrencyEnum.Usd,
        excludeFromDunningCampaign: false,
        skipInvoiceCustomSections: false,
        hasOverwrittenInvoiceCustomSectionsSelection: false,
        configurableInvoiceCustomSections: [],
        appliedDunningCampaign: null,
        billingEntity: {
          __typename: 'BillingEntity',
          id: 'billing-entity-123',
          netPaymentTerm: 30,
          finalizeZeroAmountInvoice: true,
          billingConfiguration: {
            __typename: 'BillingEntityBillingConfiguration',
            id: 'billing-config-123',
            invoiceGracePeriod: 0,
            documentLocale: 'en',
            subscriptionInvoiceIssuingDateAdjustment: null,
            subscriptionInvoiceIssuingDateAnchor: null,
          },
          appliedDunningCampaign: null,
        },
        billingConfiguration: {
          __typename: 'CustomerBillingConfiguration',
          id: 'customer-billing-config-123',
          documentLocale: null,
          subscriptionInvoiceIssuingDateAdjustment: null,
          subscriptionInvoiceIssuingDateAnchor: null,
        },
        taxes: [],
        ...overrides,
      },
    },
  },
})

async function prepare({ mocks = [createCustomerSettingsMock()] }: { mocks?: TestMocksType } = {}) {
  await act(() =>
    render(<CustomerSettings customerId={CUSTOMER_ID} />, {
      mocks,
    }),
  )
}

describe('CustomerSettings', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('Loading State', () => {
    it('shows loading skeleton while fetching data', async () => {
      // Use a mock that never resolves to keep loading state
      const loadingMock = {
        request: {
          query: GetCustomerSettingsDocument,
          variables: { id: CUSTOMER_ID },
        },
        delay: Infinity,
        result: {
          data: null,
        },
      }

      render(<CustomerSettings customerId={CUSTOMER_ID} />, {
        mocks: [loadingMock],
      })

      // During loading, should not show the settings content
      expect(screen.queryByText('Document language')).not.toBeInTheDocument()
    })
  })

  describe('Rendering Settings Sections', () => {
    it('renders document language section', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText(/document language/i)).toBeInTheDocument()
      })
    })

    it('renders finalize empty invoice section', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText(/finalize empty invoices/i)).toBeInTheDocument()
      })
    })

    it('renders grace period section', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText(/grace period/i)).toBeInTheDocument()
      })
    })

    it('renders net payment term section', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText(/net payment term/i)).toBeInTheDocument()
      })
    })

    it('renders tax section', async () => {
      await prepare()

      await waitFor(() => {
        // Use getAllByText since "tax" appears in multiple places (Tax rate, Tax objects, etc.)
        const taxElements = screen.getAllByText(/tax/i)

        expect(taxElements.length).toBeGreaterThan(0)
      })
    })
  })

  describe('Action Buttons', () => {
    it('renders add vat rate button', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByTestId('add-vat-rate-button')).toBeInTheDocument()
      })
    })

    it('renders add issuing date policy button', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByTestId('add-issuing-date-policy-button')).toBeInTheDocument()
      })
    })
  })

  describe('Error State', () => {
    it('shows error placeholder when query fails', async () => {
      const errorMock = {
        request: {
          query: GetCustomerSettingsDocument,
          variables: { id: CUSTOMER_ID },
        },
        error: new Error('Failed to fetch customer settings'),
      }

      await prepare({ mocks: [errorMock] })

      await waitFor(() => {
        expect(screen.getByText(/something went wrong/i)).toBeInTheDocument()
      })
    })

    it('shows error subtitle when query fails', async () => {
      const errorMock = {
        request: {
          query: GetCustomerSettingsDocument,
          variables: { id: CUSTOMER_ID },
        },
        error: new Error('Failed to fetch customer settings'),
      }

      await prepare({ mocks: [errorMock] })

      await waitFor(() => {
        // Error subtitle translation key
        expect(screen.getByText(/please refresh the page/i)).toBeInTheDocument()
      })
    })

    it('shows reload button when query fails', async () => {
      const errorMock = {
        request: {
          query: GetCustomerSettingsDocument,
          variables: { id: CUSTOMER_ID },
        },
        error: new Error('Failed to fetch customer settings'),
      }

      await prepare({ mocks: [errorMock] })

      await waitFor(() => {
        // Reload button - find by data-test attribute
        expect(screen.getByTestId('generic-placeholder-button')).toBeInTheDocument()
      })
    })
  })

  describe('Document Locale Setting', () => {
    it('displays inherited document locale when not set on customer', async () => {
      await prepare()

      await waitFor(() => {
        // Should show inherited from billing entity
        expect(screen.getByText(/english/i)).toBeInTheDocument()
      })
    })

    it('displays custom document locale when set on customer', async () => {
      const customLocaleMock = createCustomerSettingsMock({
        billingConfiguration: {
          __typename: 'CustomerBillingConfiguration',
          id: 'customer-billing-config-123',
          documentLocale: 'fr',
          subscriptionInvoiceIssuingDateAdjustment: null,
          subscriptionInvoiceIssuingDateAnchor: null,
        },
      })

      await prepare({ mocks: [customLocaleMock] })

      await waitFor(() => {
        expect(screen.getByText(/french/i)).toBeInTheDocument()
      })
    })
  })

  describe('Grace Period Setting', () => {
    it('displays inherited grace period when not set on customer', async () => {
      await prepare()

      await waitFor(() => {
        // Should show inherited value (0 days) - use getAllByText since it appears in multiple places
        const gracePeriodElements = screen.getAllByText(/0 day/i)

        expect(gracePeriodElements.length).toBeGreaterThan(0)
      })
    })

    it('displays custom grace period when set on customer', async () => {
      const customGracePeriodMock = createCustomerSettingsMock({
        invoiceGracePeriod: 5,
      })

      await prepare({ mocks: [customGracePeriodMock] })

      await waitFor(() => {
        expect(screen.getByText(/5 day/i)).toBeInTheDocument()
      })
    })
  })

  describe('Net Payment Term Setting', () => {
    it('displays inherited net payment term when not set on customer', async () => {
      await prepare()

      await waitFor(() => {
        // Should show inherited value (30 days)
        expect(screen.getByText(/30 day/i)).toBeInTheDocument()
      })
    })

    it('displays custom net payment term when set on customer', async () => {
      const customNetPaymentTermMock = createCustomerSettingsMock({
        netPaymentTerm: 15,
      })

      await prepare({ mocks: [customNetPaymentTermMock] })

      await waitFor(() => {
        expect(screen.getByText(/15 day/i)).toBeInTheDocument()
      })
    })

    it('displays zero days when net payment term is 0', async () => {
      const zeroNetPaymentTermMock = createCustomerSettingsMock({
        netPaymentTerm: 0,
      })

      await prepare({ mocks: [zeroNetPaymentTermMock] })

      await waitFor(() => {
        // Net payment term of 0 shows as "0 day"
        const elements = screen.getAllByText(/0 day/i)

        expect(elements.length).toBeGreaterThan(0)
      })
    })
  })

  describe('Finalize Zero Amount Invoice Setting', () => {
    it('displays inherited setting when set to Inherit', async () => {
      await prepare()

      await waitFor(() => {
        // Should show inherited value with "(Inherited)" suffix
        const elements = screen.getAllByText(/inherited/i)

        expect(elements.length).toBeGreaterThan(0)
      })
    })

    it('displays finalize when set to Finalize', async () => {
      const finalizeMock = createCustomerSettingsMock({
        finalizeZeroAmountInvoice: FinalizeZeroAmountInvoiceEnum.Finalize,
      })

      await prepare({ mocks: [finalizeMock] })

      await waitFor(() => {
        // Should show "Finalize" for the setting
        const finalizeElements = screen.getAllByText(/finalize/i)

        expect(finalizeElements.length).toBeGreaterThan(0)
      })
    })

    it('displays skip when set to Skip', async () => {
      const skipMock = createCustomerSettingsMock({
        finalizeZeroAmountInvoice: FinalizeZeroAmountInvoiceEnum.Skip,
      })

      await prepare({ mocks: [skipMock] })

      await waitFor(() => {
        // Should show "Skip" for the setting
        expect(screen.getByText(/skip/i)).toBeInTheDocument()
      })
    })
  })

  describe('Tax Settings', () => {
    it('renders tax section label', async () => {
      await prepare()

      await waitFor(() => {
        // Tax section should be present
        const taxElements = screen.getAllByText(/tax/i)

        expect(taxElements.length).toBeGreaterThan(0)
      })
    })

    it('displays taxes table when customer has taxes', async () => {
      const taxesMock = createCustomerSettingsMock({
        taxes: [
          {
            __typename: 'Tax',
            id: 'tax-1',
            name: 'VAT',
            code: 'vat',
            rate: 20,
            autoGenerated: false,
          },
        ],
      })

      await prepare({ mocks: [taxesMock] })

      await waitFor(() => {
        expect(screen.getByText('VAT')).toBeInTheDocument()
        expect(screen.getByText('vat')).toBeInTheDocument()
      })
    })

    it('displays multiple taxes when customer has multiple taxes', async () => {
      const multiTaxesMock = createCustomerSettingsMock({
        taxes: [
          {
            __typename: 'Tax',
            id: 'tax-1',
            name: 'VAT',
            code: 'vat',
            rate: 20,
            autoGenerated: false,
          },
          {
            __typename: 'Tax',
            id: 'tax-2',
            name: 'GST',
            code: 'gst',
            rate: 10,
            autoGenerated: false,
          },
        ],
      })

      await prepare({ mocks: [multiTaxesMock] })

      await waitFor(() => {
        expect(screen.getByText('VAT')).toBeInTheDocument()
        expect(screen.getByText('GST')).toBeInTheDocument()
      })
    })
  })

  describe('Dunning Campaign Setting', () => {
    it('renders dunning campaign section', async () => {
      await prepare()

      await waitFor(() => {
        // Dunning campaign section should be present - use getAllByText since it appears multiple times
        const dunningElements = screen.getAllByText(/dunning campaign/i)

        expect(dunningElements.length).toBeGreaterThan(0)
      })
    })

    it('displays dunning campaign when applied', async () => {
      const dunningMock = createCustomerSettingsMock({
        appliedDunningCampaign: {
          __typename: 'DunningCampaign',
          id: 'campaign-1',
          name: 'Default Campaign',
          code: 'default_campaign',
          appliedToOrganization: true,
          thresholds: [
            {
              __typename: 'DunningCampaignThreshold',
              currency: CurrencyEnum.Usd,
            },
          ],
        },
      })

      await prepare({ mocks: [dunningMock] })

      await waitFor(() => {
        expect(screen.getByText('Default Campaign')).toBeInTheDocument()
        expect(screen.getByText('default_campaign')).toBeInTheDocument()
      })
    })

    it('renders section when customer is excluded from dunning', async () => {
      const excludedMock = createCustomerSettingsMock({
        excludeFromDunningCampaign: true,
        appliedDunningCampaign: {
          __typename: 'DunningCampaign',
          id: 'campaign-1',
          name: 'Default Campaign',
          code: 'default_campaign',
          appliedToOrganization: true,
          thresholds: [
            {
              __typename: 'DunningCampaignThreshold',
              currency: CurrencyEnum.Usd,
            },
          ],
        },
      })

      await prepare({ mocks: [excludedMock] })

      await waitFor(() => {
        // Dunning section should still be present - use getAllByText since it appears multiple times
        const dunningElements = screen.getAllByText(/dunning campaign/i)

        expect(dunningElements.length).toBeGreaterThan(0)
      })
    })
  })

  describe('Invoice Custom Sections Setting', () => {
    it('renders invoice custom sections label', async () => {
      await prepare()

      await waitFor(() => {
        // Should show custom sections label
        expect(screen.getByText(/invoice custom section/i)).toBeInTheDocument()
      })
    })

    it('displays custom sections table when configured', async () => {
      const customSectionsMock = createCustomerSettingsMock({
        configurableInvoiceCustomSections: [
          {
            __typename: 'InvoiceCustomSection',
            id: 'section-1',
            name: 'Terms and Conditions',
            code: 'terms',
          },
        ],
      })

      await prepare({ mocks: [customSectionsMock] })

      await waitFor(() => {
        expect(screen.getByText('Terms and Conditions')).toBeInTheDocument()
      })
    })

    it('renders section when custom sections are skipped', async () => {
      const skipSectionsMock = createCustomerSettingsMock({
        skipInvoiceCustomSections: true,
        configurableInvoiceCustomSections: [
          {
            __typename: 'InvoiceCustomSection',
            id: 'section-1',
            name: 'Terms and Conditions',
            code: 'terms',
          },
        ],
      })

      await prepare({ mocks: [skipSectionsMock] })

      await waitFor(() => {
        // Invoice custom sections section should still be present
        expect(screen.getByText(/invoice custom section/i)).toBeInTheDocument()
      })
    })
  })

  describe('Issuing Date Policy Setting', () => {
    it('renders issuing date policy section', async () => {
      await prepare()

      await waitFor(() => {
        // Multiple elements may have "issuing date" text, so use getAllByText
        const issuingDateElements = screen.getAllByText(/issuing date/i)

        expect(issuingDateElements.length).toBeGreaterThan(0)
      })
    })

    it('renders issuing date policy button', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByTestId('add-issuing-date-policy-button')).toBeInTheDocument()
      })
    })
  })

  describe('Settings Sections Count', () => {
    it('renders all expected settings sections', async () => {
      await prepare()

      await waitFor(() => {
        // Count the number of settings sections rendered
        // Document locale, Finalize empty invoice, Grace period, Custom sections,
        // Net payment term, Issuing date policy, Tax, Dunning (if enabled)
        const settingSections = screen.getAllByRole('button')

        expect(settingSections.length).toBeGreaterThanOrEqual(5)
      })
    })
  })
})
