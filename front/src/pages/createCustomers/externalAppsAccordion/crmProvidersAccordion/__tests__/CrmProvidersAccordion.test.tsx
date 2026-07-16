import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import {
  AddCustomerDrawerFragment,
  CountryCode,
  CustomerAccountTypeEnum,
  HubspotIntegration,
  HubspotTargetedObjectsEnum,
  SalesforceIntegration,
  TimezoneEnum,
} from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'
import CrmProvidersAccordion from '~/pages/createCustomers/externalAppsAccordion/crmProvidersAccordion/CrmProvidersAccordion'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import { render } from '~/test-utils'

// Create mock constants for Jest mocks
const mockHubspotTargetedObjectsEnum = {
  Companies: HubspotTargetedObjectsEnum.Companies,
}

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
  hubspotCustomer: {
    __typename: 'HubspotCustomer',
    id: 'hubspot-customer-1',
    integrationId: 'hubspot-integration-1',
    externalCustomerId: 'hubspot-123',
    targetedObject: mockHubspotTargetedObjectsEnum.Companies,
    integrationCode: 'hubspot-test-code',
  },
  salesforceCustomer: {
    __typename: 'SalesforceCustomer',
    id: 'salesforce-customer-1',
    integrationId: 'salesforce-integration-1',
    externalCustomerId: 'salesforce-456',
    integrationCode: 'salesforce-test-code',
  },
  billingEntity: {
    __typename: 'BillingEntity',
    id: 'billing-entity-1',
    name: 'Test Billing Entity',
    code: 'TBE',
    euTaxManagement: false,
  },
}

// Mock the CRM providers hook
jest.mock('~/pages/createCustomers/common/useCrmProviders', () => ({
  useCrmProviders: () => ({
    crmProviders: {
      integrations: {
        collection: [
          {
            __typename: 'HubspotIntegration',
            id: 'hubspot-test-id',
            code: 'hubspot-test-code',
            name: 'Test Hubspot Integration',
            defaultTargetedObject: mockHubspotTargetedObjectsEnum.Companies,
          } as HubspotIntegration,
          {
            __typename: 'SalesforceIntegration',
            id: 'salesforce-test-id',
            code: 'salesforce-test-code',
            name: 'Test Salesforce Integration',
            instanceId: 'salesforce-instance-123',
          } as SalesforceIntegration,
        ],
      },
    },
    isLoadingCrmProviders: false,
  }),
}))

// Mock the getIntegration utility
jest.mock('~/pages/createCustomers/externalAppsAccordion/common/getIntegration', () => ({
  getIntegration: () => ({
    hadInitialIntegrationCustomer: false,
    allIntegrations: [
      {
        __typename: 'HubspotIntegration',
        id: 'hubspot-test-id',
        code: 'hubspot-test-code',
        name: 'Test Hubspot Integration',
        defaultTargetedObject: mockHubspotTargetedObjectsEnum.Companies,
      },
    ],
  }),
}))

// Create a test wrapper component that properly initializes the form
const TestCrmProvidersAccordionWrapper = ({
  setShowCrmSection = jest.fn(),
  isEdition = false,
  customer = null,
}: {
  setShowCrmSection?: jest.Mock
  isEdition?: boolean
  customer?: AddCustomerDrawerFragment | null
}) => {
  const form = useAppForm({
    defaultValues: emptyCreateCustomerDefaultValues,
  })

  return (
    <CrmProvidersAccordion
      form={form}
      setShowCrmSection={setShowCrmSection}
      isEdition={isEdition}
      customer={customer}
    />
  )
}

describe('CrmProvidersAccordion Integration Tests', () => {
  describe('WHEN rendering the component', () => {
    it('THEN should render without crashing', () => {
      const { container } = render(<TestCrmProvidersAccordionWrapper />)

      // Check that the component rendered
      expect(container.firstChild).toBeInTheDocument()
    })

    it('THEN should render a matching snapshot', () => {
      const rendered = render(<TestCrmProvidersAccordionWrapper />)

      expect(rendered.container).toMatchSnapshot()
    })

    it('THEN should render a matching snapshot after expansion', async () => {
      const user = userEvent.setup()
      const rendered = render(<TestCrmProvidersAccordionWrapper />)

      // Find and click the accordion button to expand it
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        // After expanding, check for the CRM provider selection field
        expect(screen.getByRole('combobox')).toBeInTheDocument()
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render with edition mode', async () => {
      const user = userEvent.setup()
      const rendered = render(<TestCrmProvidersAccordionWrapper isEdition={true} />)

      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render with customer data', async () => {
      const user = userEvent.setup()
      const rendered = render(
        <TestCrmProvidersAccordionWrapper customer={mockCustomer} isEdition={true} />,
      )
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)
      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })
  })

  describe('WHEN user interacts with the accordion', () => {
    it('THEN should show CRM provider selection when expanded', async () => {
      const user = userEvent.setup()

      render(<TestCrmProvidersAccordionWrapper />)

      // Find accordion buttons (there might be multiple)
      const buttons = screen.getAllByRole('button')
      const accordionButton =
        buttons.find((button) => button.getAttribute('aria-expanded') !== null) || buttons[0]

      await user.click(accordionButton)

      await waitFor(() => {
        // Should show the CRM provider combobox
        expect(screen.getByRole('combobox')).toBeInTheDocument()
      })
    })

    it('THEN should display expected accordion content', async () => {
      const user = userEvent.setup()

      const renderer = render(<TestCrmProvidersAccordionWrapper />)

      // Find and click the accordion
      const buttons = screen.getAllByRole('button')
      const accordionButton =
        buttons.find((button) => button.getAttribute('aria-expanded') !== null) || buttons[0]

      await user.click(accordionButton)

      await waitFor(() => {
        // Should show the combobox for CRM provider selection
        const combobox = screen.getByRole('combobox')

        expect(combobox).toBeInTheDocument()
        expect(renderer.container).toMatchSnapshot()

        // Should show some text content
        expect(screen.getByText(/connected account/i)).toBeInTheDocument()
      })
    })

    it('THEN should handle props correctly', () => {
      const mockSetShowCrmSection = jest.fn()

      render(<TestCrmProvidersAccordionWrapper setShowCrmSection={mockSetShowCrmSection} />)

      // Component should render without crashing with the mock function
      expect(screen.getByText('Select a connection')).toBeInTheDocument()
      // Check that we have buttons for expand/collapse and delete functionality
      expect(screen.getAllByRole('button')).toHaveLength(3)
      // Verify the mock function was passed as prop
      expect(mockSetShowCrmSection).toBeDefined()
    })
  })
})
