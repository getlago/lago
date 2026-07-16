import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { NetsuiteIntegration } from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'
import NetsuiteAccountingProviderContent from '~/pages/createCustomers/externalAppsAccordion/accountingProvidersAccordion/NetsuiteAccountingProviderContent'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import { render } from '~/test-utils'

const mockNetsuiteIntegration: NetsuiteIntegration = {
  __typename: 'NetsuiteIntegration',
  id: 'netsuite-test-id',
  code: 'netsuite-test-code',
  name: 'Test Netsuite Integration',
  connectionId: 'netsuite-conn-123',
  scriptEndpointUrl: 'https://netsuite.example.com/endpoint',
}

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
const TestNetsuiteAccountingProviderContentWrapper = ({
  hadInitialNetsuiteIntegrationCustomer = false,
  selectedNetsuiteIntegration = undefined,
  isEdition = false,
  defaultValues = emptyCreateCustomerDefaultValues,
}: {
  hadInitialNetsuiteIntegrationCustomer?: boolean
  selectedNetsuiteIntegration?: NetsuiteIntegration
  isEdition?: boolean
  defaultValues?: typeof emptyCreateCustomerDefaultValues
}) => {
  const form = useAppForm({
    defaultValues,
  })

  return (
    <NetsuiteAccountingProviderContent
      form={form}
      hadInitialNetsuiteIntegrationCustomer={hadInitialNetsuiteIntegrationCustomer}
      selectedNetsuiteIntegration={selectedNetsuiteIntegration}
      isEdition={isEdition}
    />
  )
}

describe('NetsuiteAccountingProviderContent Integration Tests', () => {
  describe('WHEN rendering the component', () => {
    it('THEN should render without crashing', async () => {
      const { container } = render(<TestNetsuiteAccountingProviderContentWrapper />)

      await waitFor(() => {
        // Check that the component rendered
        expect(container.firstChild).toBeInTheDocument()
      })
    })

    it('THEN should render a matching snapshot', async () => {
      const rendered = render(<TestNetsuiteAccountingProviderContentWrapper />)

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render with Netsuite integration data', () => {
      const rendered = render(
        <TestNetsuiteAccountingProviderContentWrapper
          selectedNetsuiteIntegration={mockNetsuiteIntegration}
        />,
      )

      expect(rendered.container).toMatchSnapshot()
    })

    it('THEN should render in edition mode', () => {
      const rendered = render(
        <TestNetsuiteAccountingProviderContentWrapper
          isEdition={true}
          selectedNetsuiteIntegration={mockNetsuiteIntegration}
        />,
      )

      expect(rendered.container).toMatchSnapshot()
    })

    it('THEN should render with initial integration customer', () => {
      const rendered = render(
        <TestNetsuiteAccountingProviderContentWrapper
          hadInitialNetsuiteIntegrationCustomer={true}
          selectedNetsuiteIntegration={mockNetsuiteIntegration}
        />,
      )

      expect(rendered.container).toMatchSnapshot()
    })
  })

  describe('WHEN user interacts with form fields', () => {
    it('THEN should display customer ID text input', () => {
      render(
        <TestNetsuiteAccountingProviderContentWrapper
          selectedNetsuiteIntegration={mockNetsuiteIntegration}
        />,
      )

      // Should have the customer ID text input
      const customerIdInput = screen.getByRole('textbox')

      expect(customerIdInput).toBeInTheDocument()
      expect(customerIdInput).toHaveAttribute('name', 'accountingCustomer.accountingCustomerId')
    })

    it('THEN should display sync with provider checkbox', () => {
      render(
        <TestNetsuiteAccountingProviderContentWrapper
          selectedNetsuiteIntegration={mockNetsuiteIntegration}
        />,
      )

      // Should have the sync checkbox
      const syncCheckbox = screen.getByRole('checkbox')

      expect(syncCheckbox).toBeInTheDocument()
      // Find the checkbox by data-test attribute on the container
      const checkboxContainer = screen.getByTestId('checkbox-accountingCustomer.syncWithProvider')

      expect(checkboxContainer).toBeInTheDocument()
    })

    it('THEN should handle user input in customer ID field', async () => {
      const user = userEvent.setup()

      render(
        <TestNetsuiteAccountingProviderContentWrapper
          selectedNetsuiteIntegration={mockNetsuiteIntegration}
        />,
      )

      const customerIdInput = screen.getByRole('textbox')

      await user.type(customerIdInput, 'netsuite-customer-123')

      expect(customerIdInput).toHaveValue('netsuite-customer-123')
    })

    it('THEN should handle sync checkbox toggle and show subsidiary field', async () => {
      const user = userEvent.setup()

      render(
        <TestNetsuiteAccountingProviderContentWrapper
          selectedNetsuiteIntegration={mockNetsuiteIntegration}
        />,
      )

      const syncCheckbox = screen.getByRole('checkbox')

      expect(syncCheckbox).not.toBeChecked()

      await user.click(syncCheckbox)
      expect(syncCheckbox).toBeChecked()

      // When sync is enabled, should show subsidiary combobox
      await waitFor(() => {
        const subsidiaryCombobox = screen.getByRole('combobox')

        expect(subsidiaryCombobox).toBeInTheDocument()
        expect(subsidiaryCombobox).toHaveAttribute('name', 'accountingCustomer.subsidiaryId')
      })
    })

    it('THEN should display subsidiary field when sync is pre-enabled', async () => {
      const renderer = render(
        <TestNetsuiteAccountingProviderContentWrapper
          selectedNetsuiteIntegration={mockNetsuiteIntegration}
          defaultValues={{
            ...emptyCreateCustomerDefaultValues,
            accountingCustomer: {
              ...emptyCreateCustomerDefaultValues.accountingCustomer,
              syncWithProvider: true,
            },
          }}
        />,
      )

      // Should have both textbox and combobox
      expect(screen.getByRole('textbox')).toBeInTheDocument() // Customer ID field
      expect(screen.getByRole('checkbox')).toBeChecked() // Sync checkbox should be checked
      expect(screen.getByRole('combobox')).toBeInTheDocument() // Subsidiary field

      expect(renderer.container).toMatchSnapshot()
    })

    it('THEN should show info alert in edition mode and with sync mode active', async () => {
      const user = userEvent.setup()

      render(
        <TestNetsuiteAccountingProviderContentWrapper
          isEdition={true}
          selectedNetsuiteIntegration={mockNetsuiteIntegration}
          hadInitialNetsuiteIntegrationCustomer={false}
        />,
      )

      const syncCheckbox = screen.getByRole('checkbox')

      expect(syncCheckbox).not.toBeChecked()

      await user.click(syncCheckbox)
      expect(syncCheckbox).toBeChecked()

      await waitFor(() => {
        // Should show info alert in edition mode with the correct text
        expect(
          screen.getByText('This customer will be created to NetSuite after editing in Lago'),
        ).toBeInTheDocument()
      })
    })
  })

  describe('WHEN component is disabled', () => {
    it('THEN should disable fields when hadInitialNetsuiteIntegrationCustomer is true', () => {
      render(
        <TestNetsuiteAccountingProviderContentWrapper
          hadInitialNetsuiteIntegrationCustomer={true}
          selectedNetsuiteIntegration={mockNetsuiteIntegration}
        />,
      )

      const customerIdInput = screen.getByRole('textbox')
      const syncCheckbox = screen.getByRole('checkbox')

      expect(customerIdInput).toBeDisabled()
      expect(syncCheckbox).toBeDisabled()
    })

    it('THEN should disable customer ID field when sync is enabled', async () => {
      const user = userEvent.setup()

      render(
        <TestNetsuiteAccountingProviderContentWrapper
          selectedNetsuiteIntegration={mockNetsuiteIntegration}
        />,
      )

      const customerIdInput = screen.getByRole('textbox')
      const syncCheckbox = screen.getByRole('checkbox')

      // Initially customer ID should be enabled
      expect(customerIdInput).not.toBeDisabled()

      // Enable sync
      await user.click(syncCheckbox)

      // Customer ID should now be disabled
      expect(customerIdInput).toBeDisabled()
    })
  })

  describe('WHEN clearing customer ID on sync toggle', () => {
    it('THEN should clear customer ID when sync is enabled (non-edition mode)', async () => {
      const user = userEvent.setup()

      render(
        <TestNetsuiteAccountingProviderContentWrapper
          selectedNetsuiteIntegration={mockNetsuiteIntegration}
          defaultValues={{
            ...emptyCreateCustomerDefaultValues,
            accountingCustomer: {
              ...emptyCreateCustomerDefaultValues.accountingCustomer,
              accountingCustomerId: 'existing-id',
            },
          }}
        />,
      )

      const customerIdInput = screen.getByRole('textbox')
      const syncCheckbox = screen.getByRole('checkbox')

      // Should have the pre-filled value
      expect(customerIdInput).toHaveValue('existing-id')

      // Enable sync (this should clear the customer ID in non-edition mode)
      await user.click(syncCheckbox)

      // Customer ID should be cleared
      expect(customerIdInput).toHaveValue('')
    })

    it('THEN should NOT clear customer ID when sync is enabled in edition mode', async () => {
      const user = userEvent.setup()

      render(
        <TestNetsuiteAccountingProviderContentWrapper
          selectedNetsuiteIntegration={mockNetsuiteIntegration}
          isEdition={true}
          defaultValues={{
            ...emptyCreateCustomerDefaultValues,
            accountingCustomer: {
              ...emptyCreateCustomerDefaultValues.accountingCustomer,
              accountingCustomerId: 'existing-id',
            },
          }}
        />,
      )

      const customerIdInput = screen.getByRole('textbox')
      const syncCheckbox = screen.getByRole('checkbox')

      // Should have the pre-filled value
      expect(customerIdInput).toHaveValue('existing-id')

      // Enable sync (this should NOT clear the customer ID in edition mode)
      await user.click(syncCheckbox)

      // Customer ID should remain
      expect(customerIdInput).toHaveValue('existing-id')
    })
  })
})
