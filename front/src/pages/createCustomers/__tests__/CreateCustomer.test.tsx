import { RenderOptions, render as rtlRender, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactElement } from 'react'

import { PspErrorCode } from '~/core/apolloClient/errorUtils'
import {
  GetAccountingIntegrationsForExternalAppsAccordionDocument,
  GetBillingEntitiesDocument,
  GetCrmIntegrationsForExternalAppsAccordionDocument,
  GetTaxIntegrationsForExternalAppsAccordionDocument,
  PaymentProvidersListForCustomerCreateEditExternalAppsAccordionDocument,
} from '~/generated/graphql'
import * as useCreateEditCustomerModule from '~/hooks/useCreateEditCustomer'
import { AllTheProviders, TestMocksType } from '~/test-utils'

import CreateCustomer from '../CreateCustomer'

// Mock data for required queries
const defaultMocks: TestMocksType = [
  {
    request: {
      query: GetBillingEntitiesDocument,
    },
    result: {
      data: {
        billingEntities: {
          __typename: 'BillingEntityCollection',
          collection: [
            {
              __typename: 'BillingEntity',
              id: '1',
              code: 'default',
              name: 'Default Entity',
              isDefault: true,
              documentNumbering: 'per_customer',
              documentNumberPrefix: 'INV',
              logoUrl: null,
              legalName: null,
              legalNumber: null,
              taxIdentificationNumber: null,
              email: null,
              addressLine1: null,
              addressLine2: null,
              zipcode: null,
              city: null,
              state: null,
              country: null,
              emailSettings: [],
              timezone: null,
              defaultCurrency: 'USD',
              euTaxManagement: false,
              selectedInvoiceCustomSections: [],
              appliedDunningCampaign: null,
              einvoicing: false,
            },
          ],
        },
      },
    },
  },
  {
    request: {
      query: PaymentProvidersListForCustomerCreateEditExternalAppsAccordionDocument,
      variables: { limit: 1000 },
    },
    result: {
      data: {
        paymentProviders: {
          __typename: 'PaymentProviderCollection',
          collection: [],
        },
      },
    },
  },
  {
    request: {
      query: GetTaxIntegrationsForExternalAppsAccordionDocument,
      variables: { limit: 1000 },
    },
    result: {
      data: {
        integrations: {
          __typename: 'IntegrationCollection',
          collection: [],
        },
      },
    },
  },
  {
    request: {
      query: GetAccountingIntegrationsForExternalAppsAccordionDocument,
      variables: { limit: 1000 },
    },
    result: {
      data: {
        integrations: {
          __typename: 'IntegrationCollection',
          collection: [],
        },
      },
    },
  },
  {
    request: {
      query: GetCrmIntegrationsForExternalAppsAccordionDocument,
      variables: { limit: 1000 },
    },
    result: {
      data: {
        integrations: {
          __typename: 'IntegrationCollection',
          collection: [],
        },
      },
    },
  },
]

// Custom render function for CreateCustomer component (create mode)
const renderCreateCustomer = (
  ui: ReactElement,
  options?: Omit<RenderOptions, 'wrapper'> & {
    mocks?: TestMocksType
    useParams?: { [key: string]: string }
  },
) =>
  rtlRender(ui, {
    wrapper: (props) => (
      <AllTheProviders
        {...props}
        mocks={options?.mocks || defaultMocks}
        useParams={options?.useParams || {}} // Empty object for create mode
        forceTypenames={true}
      />
    ),
    ...options,
  })

// Helper to wait for form to be ready (loading state finished)
const waitForFormReady = async () => {
  await waitFor(() => {
    expect(screen.getByTestId('submit-customer')).toBeInTheDocument()
    expect(screen.getByTestId('headline')).toHaveTextContent('Create a customer')
  })
}

describe('CreateCustomer Integration Tests', () => {
  describe('WHEN rendering the component', () => {
    it('THEN should render without crashing', async () => {
      renderCreateCustomer(<CreateCustomer />)

      // Basic smoke test - component should render without errors
      await waitFor(() => {
        expect(screen.getByTestId('submit-customer')).toBeInTheDocument()
      })
    })

    it('THEN should render a matching snapshot', async () => {
      const rendered = renderCreateCustomer(<CreateCustomer />)

      await waitForFormReady()
      expect(rendered.container).toMatchSnapshot()
    })
  })

  describe('WHEN checking form structure', () => {
    it('THEN should display key form elements', async () => {
      renderCreateCustomer(<CreateCustomer />)

      // Check for main form elements
      await waitFor(() => {
        expect(screen.getByTestId('submit-customer')).toBeInTheDocument()
      })
      expect(
        screen.getByRole('textbox', { name: 'Customer external ID (required)' }),
      ).toBeInTheDocument()
    })
    it('THEN should show customer information section', async () => {
      renderCreateCustomer(<CreateCustomer />)

      await waitForFormReady()

      // Look for customer information fields
      expect(screen.getByLabelText(/customer external id/i)).toBeInTheDocument()
      expect(screen.getByLabelText(/customer name/i)).toBeInTheDocument()
      expect(screen.getByLabelText(/first name/i)).toBeInTheDocument()
      expect(screen.getByLabelText(/last name/i)).toBeInTheDocument()
    })
  })

  describe('WHEN checking accordion sections', () => {
    it('THEN should display billing information accordion', async () => {
      renderCreateCustomer(<CreateCustomer />)

      await waitForFormReady()

      // Check for accordion structure
      expect(
        screen.getByRole('button', { name: /expand billing information/i }),
      ).toBeInTheDocument()
      expect(
        screen.getByText(/define the customer information to use in the invoices/i),
      ).toBeInTheDocument()
    })

    it('THEN should display metadata accordion', async () => {
      renderCreateCustomer(<CreateCustomer />)

      await waitForFormReady()

      // Check for metadata accordion
      expect(screen.getByRole('button', { name: /expand metadata/i })).toBeInTheDocument()
      expect(screen.getByText(/add metadata to the customer/i)).toBeInTheDocument()
    })

    it('THEN should display external apps accordion', async () => {
      renderCreateCustomer(<CreateCustomer />)

      await waitForFormReady()

      // Check for external apps accordion
      expect(
        screen.getByRole('button', { name: /expand connect to external apps/i }),
      ).toBeInTheDocument()
      expect(screen.getByText(/sync this customer data to an integration/i)).toBeInTheDocument()
    })
  })

  describe('WHEN checking form validation structure', () => {
    it('THEN should have form validation in place', async () => {
      renderCreateCustomer(<CreateCustomer />)

      await waitForFormReady()

      // Basic validation check - submit button should be disabled initially
      const externalIdField = screen.getByLabelText(/customer external id/i)

      expect(externalIdField).toBeInTheDocument()
      expect(externalIdField).not.toBeRequired()
    })
  })

  describe('WHEN checking on expanded features', () => {
    it('THEN should handle expanded billing information accordion', async () => {
      const user = userEvent.setup()
      const rendered = renderCreateCustomer(<CreateCustomer />)

      await waitForFormReady()

      const accordionButton = screen.getByRole('button', { name: /expand billing information/i })

      expect(accordionButton).toBeInTheDocument()
      await user.click(accordionButton)

      // Wait for accordion to expand and show address fields
      await waitFor(() => {
        // After expanding, check for address fields (both billing and shipping appear)
        expect(screen.getAllByLabelText(/address line 1/i)).toHaveLength(2) // Both billing and shipping
        expect(screen.getAllByLabelText(/city/i)).toHaveLength(2) // Both billing and shipping
        expect(screen.getAllByLabelText(/zip code/i)).toHaveLength(2) // Both billing and shipping zip codes
        // Check for country fields using text content instead of labelText since they might be select dropdowns
        expect(screen.getAllByText(/country/i)).toHaveLength(2) // Both billing and shipping
        // Snapshot after expanding accordion
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should handle expanded metadata accordion', async () => {
      const user = userEvent.setup()
      const rendered = renderCreateCustomer(<CreateCustomer />)

      await waitForFormReady()

      const accordionButton = screen.getByRole('button', { name: /expand metadata/i })

      expect(accordionButton).toBeInTheDocument()
      await user.click(accordionButton)

      // Wait for accordion to expand and show address fields
      await waitFor(async () => {
        // After expanding, check for metadata button
        const metadataButton = screen.getByRole('button', { name: 'Add metadata' })

        expect(metadataButton).toBeInTheDocument()
        //Snapshot now
        expect(rendered.container).toMatchSnapshot()
        await user.click(accordionButton)

        //Snapshot after adding field
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should handle expanded external apps accordion', async () => {
      const user = userEvent.setup()
      const rendered = renderCreateCustomer(<CreateCustomer />)

      await waitForFormReady()

      const accordionButton = screen.getByRole('button', {
        name: /expand connect to external apps/i,
      })

      expect(accordionButton).toBeInTheDocument()
      await user.click(accordionButton)

      // Wait for accordion to expand and show address fields
      await waitFor(async () => {
        // After expanding, check for external apps fields
        const connectionButton = screen.getByRole('button', { name: 'Add a connection' })

        expect(connectionButton).toBeInTheDocument()
        // Snapshot after expanding accordion
        expect(rendered.container).toMatchSnapshot()

        await user.click(connectionButton)
        // Snapshot after expanding popover
        expect(rendered.container).toMatchSnapshot()
      })
    })
  })

  describe('WHEN checking premium features', () => {
    it('THEN should handle partner account toggle visibility', async () => {
      renderCreateCustomer(<CreateCustomer />)

      await waitForFormReady()

      // Check basic structure for premium features
      expect(screen.getByLabelText(/isPartner/i)).toBeInTheDocument()
      expect(screen.getByText(/Entity that sells your products or services/i)).toBeInTheDocument()
    })
  })

  describe('WHEN checking navigation elements', () => {
    it('THEN should display navigation buttons', async () => {
      renderCreateCustomer(<CreateCustomer />)

      // Check for navigation/action buttons
      await waitFor(() => {
        expect(screen.getByTestId('submit-customer')).toBeInTheDocument()
      })
    })
  })

  describe('WHEN checking form sections are present', () => {
    it('THEN should display key form elements', async () => {
      renderCreateCustomer(<CreateCustomer />)

      // Verify major sections are present
      await waitFor(() => {
        expect(screen.getByTestId('submit-customer')).toBeInTheDocument()
      })
      expect(screen.getByTestId('headline')).toHaveTextContent('Create a customer')
      expect(screen.getByRole('button', { name: /create customer/i })).toBeInTheDocument()
    })
  })

  describe('WHEN checking loading states', () => {
    it('THEN should handle loading states gracefully', async () => {
      renderCreateCustomer(<CreateCustomer />)

      // Basic loading state check
      await waitFor(() => {
        expect(screen.getByTestId('submit-customer')).toBeInTheDocument()
      })
      // Component should render without loading indicators initially
      expect(screen.queryByRole('progressbar')).not.toBeInTheDocument()
    })
  })

  describe('WHEN checking component accessibility', () => {
    it('THEN should have proper ARIA labels and roles', async () => {
      renderCreateCustomer(<CreateCustomer />)

      // Check for proper accessibility attributes
      await waitFor(() => {
        expect(screen.getByTestId('submit-customer')).toBeInTheDocument()
      })
      expect(screen.getByLabelText(/customer external id/i)).toHaveAttribute(
        'aria-invalid',
        'false',
      )
      expect(screen.getByRole('button', { name: /create customer/i })).toBeInTheDocument()
    })
  })

  describe('WHEN handling form submission errors', () => {
    let hookSpy: jest.SpyInstance
    const mockOnSave = jest.fn()
    const mockOnClose = jest.fn()

    beforeEach(() => {
      hookSpy = jest.spyOn(useCreateEditCustomerModule, 'useCreateEditCustomer').mockReturnValue({
        isEdition: false,
        loading: false,
        customer: undefined,
        onClose: mockOnClose,
        onSave: mockOnSave,
      })
      mockOnSave.mockReset()
    })

    afterEach(() => {
      hookSpy.mockRestore()
    })

    it('THEN should show error on externalId when ValueAlreadyExist error is returned', async () => {
      const user = userEvent.setup()

      mockOnSave.mockResolvedValue({
        errors: [
          {
            message: 'Unprocessable Entity',
            extensions: {
              status: 422,
              code: 'unprocessable_entity',
              details: { externalId: ['value_already_exist'] },
            },
          },
        ],
      })

      renderCreateCustomer(<CreateCustomer />)
      await waitForFormReady()

      const externalIdInput = screen.getByLabelText(/customer external id/i)

      await user.type(externalIdInput, 'test-customer')

      const submitButton = screen.getByTestId('submit-customer')

      await user.click(submitButton)

      await waitFor(() => {
        expect(mockOnSave).toHaveBeenCalled()
      })

      await waitFor(() => {
        expect(externalIdInput).toHaveAttribute('aria-invalid', 'true')
      })
    })

    it('THEN should not reset form when Stripe third-party error is returned', async () => {
      const user = userEvent.setup()

      mockOnSave.mockResolvedValue({
        errors: [
          {
            message: 'Unprocessable Entity',
            locations: [{ line: 2, column: 3 }],
            path: ['createCustomer'],
            extensions: {
              status: 422,
              code: PspErrorCode.ThirdPartyError,
              details: {
                error: "Stripe: resource_missing - No such customer: 'non-existing'",
              },
            },
          },
        ],
      })

      renderCreateCustomer(<CreateCustomer />)
      await waitForFormReady()

      const externalIdInput = screen.getByLabelText(/customer external id/i)

      await user.type(externalIdInput, 'test-customer')

      const submitButton = screen.getByTestId('submit-customer')

      await user.click(submitButton)

      await waitFor(() => {
        expect(mockOnSave).toHaveBeenCalled()
      })

      // Form should NOT have been reset — error was caught and returned early
      await waitFor(() => {
        expect(externalIdInput).toHaveValue('test-customer')
      })
    })

    it('THEN should reset form when non-Stripe third-party error is returned', async () => {
      const user = userEvent.setup()

      mockOnSave.mockResolvedValue({
        errors: [
          {
            message: 'Third Party Error',
            extensions: {
              status: 422,
              code: PspErrorCode.ThirdPartyError,
              details: {
                error: 'SomeOtherProvider: some error message',
              },
            },
          },
        ],
      })

      renderCreateCustomer(<CreateCustomer />)
      await waitForFormReady()

      const externalIdInput = screen.getByLabelText(/customer external id/i)

      await user.type(externalIdInput, 'test-customer')

      const submitButton = screen.getByTestId('submit-customer')

      await user.click(submitButton)

      await waitFor(() => {
        expect(mockOnSave).toHaveBeenCalled()
      })

      // Form should have been reset — non-Stripe error falls through
      await waitFor(() => {
        expect(externalIdInput).toHaveValue('')
      })
    })
  })
})
