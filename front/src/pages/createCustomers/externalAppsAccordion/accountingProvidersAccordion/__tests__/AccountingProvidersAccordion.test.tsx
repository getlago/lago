import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import {
  AddCustomerDrawerFragment,
  CountryCode,
  CustomerAccountTypeEnum,
  NetsuiteIntegration,
  TimezoneEnum,
  XeroIntegration,
} from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'
import AccountingProvidersAccordion from '~/pages/createCustomers/externalAppsAccordion/accountingProvidersAccordion/AccountingProvidersAccordion'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import { render } from '~/test-utils'

const mockCustomer: AddCustomerDrawerFragment = {
  id: 'test-customer-id',
  canEditAttributes: true,
  applicableTimezone: TimezoneEnum.TzAfricaAlgiers,
  externalId: 'CUST-001',
  accountType: CustomerAccountTypeEnum.Customer,
  addressLine1: '123 Test St',
  addressLine2: 'Suite 100',
  city: 'Testville',
  state: 'TS',
  zipcode: '12345',
  country: CountryCode.Us,
  phone: '+1234567890',
  email: 'email@email.com',
  netsuiteCustomer: {
    __typename: 'NetsuiteCustomer',
    id: 'netsuite-customer-1',
    integrationId: 'netsuite-integration-1',
    externalCustomerId: 'netsuite-123',
    integrationCode: 'netsuite-test-code',
    subsidiaryId: 'subsidiary-456',
    syncWithProvider: true,
  },
  xeroCustomer: {
    __typename: 'XeroCustomer',
    id: 'xero-customer-1',
    integrationId: 'xero-integration-1',
    externalCustomerId: 'xero-456',
    integrationCode: 'xero-test-code',
    syncWithProvider: false,
  },
  billingEntity: {
    __typename: 'BillingEntity',
    id: 'billing-entity-1',
    name: 'Test Billing Entity',
    code: 'TBE',
    euTaxManagement: false,
  },
}

// Mock the accounting providers hook
jest.mock('~/pages/createCustomers/common/useAccountingProviders', () => ({
  useAccountingProviders: () => ({
    accountingProviders: {
      integrations: {
        collection: [
          {
            __typename: 'NetsuiteIntegration',
            id: 'netsuite-test-id',
            code: 'netsuite-test-code',
            name: 'Test Netsuite Integration',
            connectionId: 'netsuite-conn-123',
            scriptEndpointUrl: 'https://netsuite.example.com/endpoint',
          } as NetsuiteIntegration,
          {
            __typename: 'XeroIntegration',
            id: 'xero-test-id',
            code: 'xero-test-code',
            name: 'Test Xero Integration',
            connectionId: 'xero-conn-456',
          } as XeroIntegration,
        ],
      },
    },
    isLoadingAccountProviders: false,
  }),
}))

// Mock the getIntegration utility
jest.mock('~/pages/createCustomers/externalAppsAccordion/common/getIntegration', () => ({
  getIntegration: () => ({
    hadInitialIntegrationCustomer: false,
    allIntegrations: [
      {
        __typename: 'NetsuiteIntegration',
        id: 'netsuite-test-id',
        code: 'netsuite-test-code',
        name: 'Test Netsuite Integration',
        connectionId: 'netsuite-conn-123',
        scriptEndpointUrl: 'https://netsuite.example.com/endpoint',
      },
    ],
  }),
}))

// Mock the subsidiaries hook
jest.mock(
  '~/pages/createCustomers/externalAppsAccordion/accountingProvidersAccordion/useAccountingProvidersSubsidaries',
  () => ({
    useAccountingProvidersSubsidaries: () => ({
      subsidiariesData: {
        integrationSubsidiaries: {
          collection: [
            {
              externalId: 'subsidiary-1',
              externalName: 'Test Subsidiary 1',
            },
            {
              externalId: 'subsidiary-2',
              externalName: 'Test Subsidiary 2',
            },
          ],
        },
      },
    }),
  }),
)

// Create a test wrapper component that properly initializes the form
const TestAccountingProvidersAccordionWrapper = ({
  setShowAccountingSection = jest.fn(),
  isEdition = false,
  customer = null,
}: {
  setShowAccountingSection?: jest.Mock
  isEdition?: boolean
  customer?: AddCustomerDrawerFragment | null
}) => {
  const form = useAppForm({
    defaultValues: emptyCreateCustomerDefaultValues,
  })

  return (
    <AccountingProvidersAccordion
      form={form}
      setShowAccountingSection={setShowAccountingSection}
      isEdition={isEdition}
      customer={customer}
    />
  )
}

describe('AccountingProvidersAccordion Integration Tests', () => {
  describe('WHEN rendering the component', () => {
    it('THEN should render without crashing', async () => {
      const { container } = render(<TestAccountingProvidersAccordionWrapper />)

      // Check that the component rendered
      await waitFor(() => {
        expect(container.firstChild).toBeInTheDocument()
      })
    })

    it('THEN should render a matching snapshot', async () => {
      const rendered = render(<TestAccountingProvidersAccordionWrapper />)

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render a matching snapshot after expansion', async () => {
      const user = userEvent.setup()
      const rendered = render(<TestAccountingProvidersAccordionWrapper />)

      // Find and click the accordion button to expand it
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        // After expanding, check for the accounting provider selection field
        expect(screen.getByRole('combobox')).toBeInTheDocument()
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render with edition mode', async () => {
      const user = userEvent.setup()
      const rendered = render(<TestAccountingProvidersAccordionWrapper isEdition={true} />)

      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render with customer data', async () => {
      const user = userEvent.setup()
      const rendered = render(
        <TestAccountingProvidersAccordionWrapper customer={mockCustomer} isEdition={true} />,
      )
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)
      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })
  })

  describe('WHEN user interacts with the accordion', () => {
    it('THEN should show accounting provider selection when expanded', async () => {
      const user = userEvent.setup()

      render(<TestAccountingProvidersAccordionWrapper />)

      // Find accordion buttons (there might be multiple)
      const buttons = screen.getAllByRole('button')
      const accordionButton =
        buttons.find((button) => button.getAttribute('aria-expanded') !== null) || buttons[0]

      await user.click(accordionButton)

      await waitFor(() => {
        // Should show the accounting provider combobox
        expect(screen.getByRole('combobox')).toBeInTheDocument()
      })
    })

    it('THEN should display expected accordion content', async () => {
      const user = userEvent.setup()

      const renderer = render(<TestAccountingProvidersAccordionWrapper />)

      // Find and click the accordion
      const buttons = screen.getAllByRole('button')
      const accordionButton =
        buttons.find((button) => button.getAttribute('aria-expanded') !== null) || buttons[0]

      await user.click(accordionButton)

      await waitFor(() => {
        // Should show the combobox for accounting provider selection
        const combobox = screen.getByRole('combobox')

        expect(combobox).toBeInTheDocument()
        expect(renderer.container).toMatchSnapshot()

        // Should show some text content
        expect(screen.getByText(/connected account/i)).toBeInTheDocument()
      })
    })

    it('THEN should handle props correctly', async () => {
      const mockSetShowAccountingSection = jest.fn()

      render(
        <TestAccountingProvidersAccordionWrapper
          setShowAccountingSection={mockSetShowAccountingSection}
        />,
      )

      await waitFor(() => {
        // Component should render without crashing with the mock function
        expect(screen.getByText('Select a connection')).toBeInTheDocument()
        // Check that we have buttons for expand/collapse and delete functionality
        expect(screen.getAllByRole('button')).toHaveLength(3)
        // Verify the mock function was passed as prop
        expect(mockSetShowAccountingSection).toBeDefined()
      })
    })
  })
})
