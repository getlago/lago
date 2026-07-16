import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { XeroIntegration } from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'
import XeroAccountingProviderContent from '~/pages/createCustomers/externalAppsAccordion/accountingProvidersAccordion/XeroAccountingProviderContent'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import { render } from '~/test-utils'

const mockXeroIntegration: XeroIntegration = {
  __typename: 'XeroIntegration',
  id: 'xero-test-id',
  code: 'xero-test-code',
  name: 'Test Xero Integration',
  connectionId: 'xero-conn-456',
}

// Create a test wrapper component that properly initializes the form
const TestXeroAccountingProviderContentWrapper = ({
  hadInitialXeroIntegrationCustomer = false,
  selectedXeroIntegration = undefined,
  isEdition = false,
  defaultValues = emptyCreateCustomerDefaultValues,
}: {
  hadInitialXeroIntegrationCustomer?: boolean
  selectedXeroIntegration?: XeroIntegration
  isEdition?: boolean
  defaultValues?: typeof emptyCreateCustomerDefaultValues
}) => {
  const form = useAppForm({
    defaultValues,
  })

  return (
    <XeroAccountingProviderContent
      form={form}
      hadInitialXeroIntegrationCustomer={hadInitialXeroIntegrationCustomer}
      selectedXeroIntegration={selectedXeroIntegration}
      isEdition={isEdition}
    />
  )
}

describe('XeroAccountingProviderContent Integration Tests', () => {
  describe('WHEN rendering the component', () => {
    it('THEN should render without crashing', async () => {
      const { container } = render(<TestXeroAccountingProviderContentWrapper />)

      // Check that the component rendered
      await waitFor(() => {
        expect(container).toBeInTheDocument()
      })
    })

    it('THEN should render a matching snapshot', () => {
      const rendered = render(<TestXeroAccountingProviderContentWrapper />)

      expect(rendered.container).toMatchSnapshot()
    })

    it('THEN should render with Xero integration data', () => {
      const rendered = render(
        <TestXeroAccountingProviderContentWrapper selectedXeroIntegration={mockXeroIntegration} />,
      )

      expect(rendered.container).toMatchSnapshot()
    })

    it('THEN should render in edition mode', () => {
      const rendered = render(
        <TestXeroAccountingProviderContentWrapper
          isEdition={true}
          selectedXeroIntegration={mockXeroIntegration}
        />,
      )

      expect(rendered.container).toMatchSnapshot()
    })

    it('THEN should render with initial integration customer', () => {
      const rendered = render(
        <TestXeroAccountingProviderContentWrapper
          hadInitialXeroIntegrationCustomer={true}
          selectedXeroIntegration={mockXeroIntegration}
        />,
      )

      expect(rendered.container).toMatchSnapshot()
    })
  })

  describe('WHEN user interacts with form fields', () => {
    it('THEN should display customer ID text input', () => {
      render(
        <TestXeroAccountingProviderContentWrapper selectedXeroIntegration={mockXeroIntegration} />,
      )

      // Should have the customer ID text input
      const customerIdInput = screen.getByRole('textbox')

      expect(customerIdInput).toBeInTheDocument()
      expect(customerIdInput).toHaveAttribute('name', 'accountingCustomer.accountingCustomerId')
    })

    it('THEN should display sync with provider checkbox', () => {
      render(
        <TestXeroAccountingProviderContentWrapper selectedXeroIntegration={mockXeroIntegration} />,
      )

      // Should have the sync checkbox
      const syncCheckbox = screen.getByRole('checkbox')

      expect(syncCheckbox).toBeInTheDocument()
      // Check if the parent label has the expected data-test attribute
      const syncCheckboxLabel = syncCheckbox.closest('label')

      expect(syncCheckboxLabel).toHaveAttribute(
        'data-test',
        'checkbox-accountingCustomer.syncWithProvider',
      )
    })

    it('THEN should handle user input in customer ID field', async () => {
      const user = userEvent.setup()

      render(
        <TestXeroAccountingProviderContentWrapper selectedXeroIntegration={mockXeroIntegration} />,
      )

      const customerIdInput = screen.getByRole('textbox')

      await user.type(customerIdInput, 'xero-customer-456')

      expect(customerIdInput).toHaveValue('xero-customer-456')
    })

    it('THEN should handle sync checkbox toggle', async () => {
      const user = userEvent.setup()

      render(
        <TestXeroAccountingProviderContentWrapper selectedXeroIntegration={mockXeroIntegration} />,
      )

      const syncCheckbox = screen.getByRole('checkbox')

      expect(syncCheckbox).not.toBeChecked()

      await user.click(syncCheckbox)
      expect(syncCheckbox).toBeChecked()
    })

    it('THEN should display correct checkbox label with integration name', () => {
      render(
        <TestXeroAccountingProviderContentWrapper selectedXeroIntegration={mockXeroIntegration} />,
      )

      // Should show checkbox with integration name
      expect(screen.getByText(/Test Xero Integration/)).toBeInTheDocument()
    })

    it('THEN should display default Xero name when integration name is not available', () => {
      const integrationWithoutName = { ...mockXeroIntegration, name: undefined }

      render(
        <TestXeroAccountingProviderContentWrapper
          // @ts-expect-error Testing a case that shouldn't happen
          selectedXeroIntegration={integrationWithoutName}
        />,
      )

      // Should show checkbox with default Xero name
      expect(screen.getByText('Create automatically this customer in Xero')).toBeInTheDocument()
    })
  })

  describe('WHEN component is disabled', () => {
    it('THEN should disable fields when hadInitialXeroIntegrationCustomer is true', () => {
      render(
        <TestXeroAccountingProviderContentWrapper
          hadInitialXeroIntegrationCustomer={true}
          selectedXeroIntegration={mockXeroIntegration}
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
        <TestXeroAccountingProviderContentWrapper selectedXeroIntegration={mockXeroIntegration} />,
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

    it('THEN should show customer ID field as disabled when sync is pre-enabled', () => {
      render(
        <TestXeroAccountingProviderContentWrapper
          selectedXeroIntegration={mockXeroIntegration}
          defaultValues={{
            ...emptyCreateCustomerDefaultValues,
            accountingCustomer: {
              ...emptyCreateCustomerDefaultValues.accountingCustomer,
              syncWithProvider: true,
            },
          }}
        />,
      )

      const customerIdInput = screen.getByRole('textbox')
      const syncCheckbox = screen.getByRole('checkbox')

      expect(customerIdInput).toBeDisabled()
      expect(syncCheckbox).toBeChecked()
    })
  })

  describe('WHEN clearing customer ID on sync toggle', () => {
    it('THEN should clear customer ID when sync is enabled (non-edition mode)', async () => {
      const user = userEvent.setup()

      render(
        <TestXeroAccountingProviderContentWrapper
          selectedXeroIntegration={mockXeroIntegration}
          defaultValues={{
            ...emptyCreateCustomerDefaultValues,
            accountingCustomer: {
              ...emptyCreateCustomerDefaultValues.accountingCustomer,
              accountingCustomerId: 'existing-xero-id',
            },
          }}
        />,
      )

      const customerIdInput = screen.getByRole('textbox')
      const syncCheckbox = screen.getByRole('checkbox')

      // Should have the pre-filled value
      expect(customerIdInput).toHaveValue('existing-xero-id')

      // Enable sync (this should clear the customer ID in non-edition mode)
      await user.click(syncCheckbox)

      // Customer ID should be cleared
      expect(customerIdInput).toHaveValue('')
    })

    it('THEN should NOT clear customer ID when sync is enabled in edition mode', async () => {
      const user = userEvent.setup()

      render(
        <TestXeroAccountingProviderContentWrapper
          selectedXeroIntegration={mockXeroIntegration}
          isEdition={true}
          defaultValues={{
            ...emptyCreateCustomerDefaultValues,
            accountingCustomer: {
              ...emptyCreateCustomerDefaultValues.accountingCustomer,
              accountingCustomerId: 'existing-xero-id',
            },
          }}
        />,
      )

      const customerIdInput = screen.getByRole('textbox')
      const syncCheckbox = screen.getByRole('checkbox')

      // Should have the pre-filled value
      expect(customerIdInput).toHaveValue('existing-xero-id')

      // Enable sync (this should NOT clear the customer ID in edition mode)
      await user.click(syncCheckbox)

      // Customer ID should remain
      expect(customerIdInput).toHaveValue('existing-xero-id')
    })

    it('THEN should not clear customer ID when sync is disabled', async () => {
      const user = userEvent.setup()

      render(
        <TestXeroAccountingProviderContentWrapper
          selectedXeroIntegration={mockXeroIntegration}
          defaultValues={{
            ...emptyCreateCustomerDefaultValues,
            accountingCustomer: {
              ...emptyCreateCustomerDefaultValues.accountingCustomer,
              accountingCustomerId: 'existing-xero-id',
              syncWithProvider: true,
            },
          }}
        />,
      )

      const customerIdInput = screen.getByRole('textbox')
      const syncCheckbox = screen.getByRole('checkbox')

      // Should have the pre-filled value and sync enabled
      expect(customerIdInput).toHaveValue('existing-xero-id')
      expect(syncCheckbox).toBeChecked()

      // Disable sync (this should not clear the customer ID)
      await user.click(syncCheckbox)

      // Customer ID should remain
      expect(customerIdInput).toHaveValue('existing-xero-id')
      expect(syncCheckbox).not.toBeChecked()
    })
  })

  describe('WHEN form validation', () => {
    it('THEN should properly handle form field names', () => {
      render(
        <TestXeroAccountingProviderContentWrapper selectedXeroIntegration={mockXeroIntegration} />,
      )

      const customerIdInput = screen.getByRole('textbox')
      const syncCheckbox = screen.getByRole('checkbox')

      // Check that fields have correct names for form handling
      expect(customerIdInput).toHaveAttribute('name', 'accountingCustomer.accountingCustomerId')
      // Check that checkbox label has the expected data-test attribute
      const syncCheckboxLabel = syncCheckbox.closest('label')

      expect(syncCheckboxLabel).toHaveAttribute(
        'data-test',
        'checkbox-accountingCustomer.syncWithProvider',
      )
    })
  })
})
