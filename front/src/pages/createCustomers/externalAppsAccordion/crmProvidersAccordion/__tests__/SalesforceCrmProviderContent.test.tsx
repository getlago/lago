import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { SalesforceIntegration } from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'
import SalesforceCrmProviderContent from '~/pages/createCustomers/externalAppsAccordion/crmProvidersAccordion/SalesforceCrmProviderContent'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import { render } from '~/test-utils'

const mockSalesforceIntegration: SalesforceIntegration = {
  __typename: 'SalesforceIntegration',
  id: 'salesforce-test-id',
  code: 'salesforce-test-code',
  name: 'Test Salesforce Integration',
  instanceId: 'salesforce-instance-123',
}

// Create a test wrapper component that properly initializes the form
const TestSalesforceCrmProviderContentWrapper = ({
  hadInitialSalesforceIntegrationCustomer = false,
  selectedSalesforceIntegration = undefined,
  isEdition = false,
}: {
  hadInitialSalesforceIntegrationCustomer?: boolean
  selectedSalesforceIntegration?: SalesforceIntegration
  isEdition?: boolean
}) => {
  const form = useAppForm({
    defaultValues: emptyCreateCustomerDefaultValues,
  })

  return (
    <SalesforceCrmProviderContent
      form={form}
      hadInitialSalesforceIntegrationCustomer={hadInitialSalesforceIntegrationCustomer}
      selectedSalesforceIntegration={selectedSalesforceIntegration}
      isEdition={isEdition}
    />
  )
}

describe('SalesforceCrmProviderContent Integration Tests', () => {
  describe('WHEN rendering the component', () => {
    it('THEN should render without crashing', async () => {
      const { container } = render(<TestSalesforceCrmProviderContentWrapper />)

      await waitFor(() => {
        // Check that the component rendered
        expect(container.firstChild).toBeInTheDocument()
      })
    })

    it('THEN should render a matching snapshot', async () => {
      const rendered = render(<TestSalesforceCrmProviderContentWrapper />)

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render with Salesforce integration data', async () => {
      const rendered = render(
        <TestSalesforceCrmProviderContentWrapper
          selectedSalesforceIntegration={mockSalesforceIntegration}
        />,
      )

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render in edition mode', async () => {
      const rendered = render(
        <TestSalesforceCrmProviderContentWrapper
          isEdition={true}
          selectedSalesforceIntegration={mockSalesforceIntegration}
        />,
      )

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render with initial integration customer', async () => {
      const rendered = render(
        <TestSalesforceCrmProviderContentWrapper
          hadInitialSalesforceIntegrationCustomer={true}
          selectedSalesforceIntegration={mockSalesforceIntegration}
        />,
      )

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })
  })

  describe('WHEN user interacts with form fields', () => {
    it('THEN should display CRM customer ID field', () => {
      render(
        <TestSalesforceCrmProviderContentWrapper
          selectedSalesforceIntegration={mockSalesforceIntegration}
        />,
      )

      // Should have the customer ID text input
      const customerIdInput = screen.getByRole('textbox')

      expect(customerIdInput).toBeInTheDocument()
    })

    it('THEN should display sync with provider checkbox', () => {
      render(
        <TestSalesforceCrmProviderContentWrapper
          selectedSalesforceIntegration={mockSalesforceIntegration}
        />,
      )

      // Should have the sync checkbox
      const syncCheckbox = screen.getByRole('checkbox')

      expect(syncCheckbox).toBeInTheDocument()
    })

    it('THEN should handle user input in customer ID field', async () => {
      const user = userEvent.setup()

      render(
        <TestSalesforceCrmProviderContentWrapper
          selectedSalesforceIntegration={mockSalesforceIntegration}
        />,
      )

      const customerIdInput = screen.getByRole('textbox')

      await user.type(customerIdInput, 'test-customer-id')

      expect(customerIdInput).toHaveValue('test-customer-id')
    })

    it('THEN should handle sync checkbox toggle', async () => {
      const user = userEvent.setup()

      render(
        <TestSalesforceCrmProviderContentWrapper
          selectedSalesforceIntegration={mockSalesforceIntegration}
        />,
      )

      const syncCheckbox = screen.getByRole('checkbox')

      expect(syncCheckbox).not.toBeChecked()

      await user.click(syncCheckbox)
      expect(syncCheckbox).toBeChecked()
    })
  })

  describe('WHEN component is disabled', () => {
    it('THEN should disable fields when hadInitialSalesforceIntegrationCustomer is true', () => {
      render(
        <TestSalesforceCrmProviderContentWrapper
          hadInitialSalesforceIntegrationCustomer={true}
          selectedSalesforceIntegration={mockSalesforceIntegration}
        />,
      )

      const customerIdInput = screen.getByRole('textbox')
      const syncCheckbox = screen.getByRole('checkbox')

      expect(customerIdInput).toBeDisabled()
      expect(syncCheckbox).toBeDisabled()
    })
  })
})
