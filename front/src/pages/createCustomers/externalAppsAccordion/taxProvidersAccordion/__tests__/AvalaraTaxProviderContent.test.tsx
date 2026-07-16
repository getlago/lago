import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { AvalaraIntegration } from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'
import AvalaraTaxProviderContent from '~/pages/createCustomers/externalAppsAccordion/taxProvidersAccordion/AvalaraTaxProviderContent'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import { render } from '~/test-utils'

const mockAvalaraIntegration: AvalaraIntegration = {
  __typename: 'AvalaraIntegration',
  id: 'avalara-test-id',
  code: 'avalara-test-code',
  name: 'Test Avalara Integration',
  companyCode: 'avalara-company-123',
  licenseKey: 'avalara-license-key-123',
}

// Create a test wrapper component that properly initializes the form
const TestAvalaraTaxProviderContentWrapper = ({
  hadInitialAvalaraIntegrationCustomer = false,
  selectedAvalaraIntegration = undefined,
  isEdition = false,
  defaultValues = emptyCreateCustomerDefaultValues,
}: {
  hadInitialAvalaraIntegrationCustomer?: boolean
  selectedAvalaraIntegration?: AvalaraIntegration
  isEdition?: boolean
  defaultValues?: typeof emptyCreateCustomerDefaultValues
}) => {
  const form = useAppForm({
    defaultValues,
  })

  return (
    <AvalaraTaxProviderContent
      form={form}
      hadInitialAvalaraIntegrationCustomer={hadInitialAvalaraIntegrationCustomer}
      selectedAvalaraIntegration={selectedAvalaraIntegration}
      isEdition={isEdition}
    />
  )
}

describe('AvalaraTaxProviderContent Integration Tests', () => {
  describe('WHEN rendering the component', () => {
    it('THEN should render without crashing', async () => {
      const { container } = render(<TestAvalaraTaxProviderContentWrapper />)

      // Check that the component rendered
      await waitFor(() => {
        expect(container.firstChild).toBeInTheDocument()
      })
    })

    it('THEN should render a matching snapshot', async () => {
      const rendered = render(<TestAvalaraTaxProviderContentWrapper />)

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render with Avalara integration data', async () => {
      const rendered = render(
        <TestAvalaraTaxProviderContentWrapper
          selectedAvalaraIntegration={mockAvalaraIntegration}
        />,
      )

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render in edition mode', async () => {
      const rendered = render(
        <TestAvalaraTaxProviderContentWrapper
          isEdition={true}
          selectedAvalaraIntegration={mockAvalaraIntegration}
        />,
      )

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render with initial integration customer', async () => {
      const rendered = render(
        <TestAvalaraTaxProviderContentWrapper
          hadInitialAvalaraIntegrationCustomer={true}
          selectedAvalaraIntegration={mockAvalaraIntegration}
        />,
      )

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })
  })

  describe('WHEN user interacts with form fields', () => {
    it('THEN should display tax customer ID field', () => {
      render(
        <TestAvalaraTaxProviderContentWrapper
          selectedAvalaraIntegration={mockAvalaraIntegration}
        />,
      )

      // Should have the tax customer ID text input
      const taxCustomerIdInput = screen.getByRole('textbox')

      expect(taxCustomerIdInput).toBeInTheDocument()
      expect(taxCustomerIdInput).toHaveAttribute('name', 'taxCustomer.taxCustomerId')
    })

    it('THEN should display sync with provider checkbox', () => {
      render(
        <TestAvalaraTaxProviderContentWrapper
          selectedAvalaraIntegration={mockAvalaraIntegration}
        />,
      )

      // Should have the sync checkbox
      const syncCheckbox = screen.getByRole('checkbox')

      expect(syncCheckbox).toBeInTheDocument()
      // Checkbox doesn't have a name attribute in this implementation, but it should be present
      expect(syncCheckbox).toHaveAttribute('aria-labelledby')
    })

    it('THEN should handle user input in tax customer ID field', async () => {
      const user = userEvent.setup()

      render(
        <TestAvalaraTaxProviderContentWrapper
          selectedAvalaraIntegration={mockAvalaraIntegration}
        />,
      )

      const taxCustomerIdInput = screen.getByRole('textbox')

      await user.type(taxCustomerIdInput, 'avalara-customer-123')

      expect(taxCustomerIdInput).toHaveValue('avalara-customer-123')
    })

    it('THEN should handle sync checkbox toggle', async () => {
      const user = userEvent.setup()

      render(
        <TestAvalaraTaxProviderContentWrapper
          selectedAvalaraIntegration={mockAvalaraIntegration}
        />,
      )

      const syncCheckbox = screen.getByRole('checkbox')

      expect(syncCheckbox).not.toBeChecked()

      await user.click(syncCheckbox)
      expect(syncCheckbox).toBeChecked()
    })

    it('THEN should disable tax customer ID when sync is enabled', async () => {
      const user = userEvent.setup()

      render(
        <TestAvalaraTaxProviderContentWrapper
          selectedAvalaraIntegration={mockAvalaraIntegration}
        />,
      )

      const taxCustomerIdInput = screen.getByRole('textbox')
      const syncCheckbox = screen.getByRole('checkbox')

      // Initially both should be enabled
      expect(taxCustomerIdInput).not.toBeDisabled()
      expect(syncCheckbox).not.toBeDisabled()

      // Enable sync
      await user.click(syncCheckbox)

      // Tax customer ID should now be disabled
      expect(taxCustomerIdInput).toBeDisabled()
    })

    it('THEN should clear tax customer ID when sync is enabled and not in edition mode', async () => {
      const user = userEvent.setup()

      render(
        <TestAvalaraTaxProviderContentWrapper
          selectedAvalaraIntegration={mockAvalaraIntegration}
          defaultValues={{
            ...emptyCreateCustomerDefaultValues,
            taxCustomer: {
              taxCustomerId: 'existing-id',
              syncWithProvider: false,
            },
          }}
        />,
      )

      const taxCustomerIdInput = screen.getByRole('textbox')
      const syncCheckbox = screen.getByRole('checkbox')

      // Input should have the existing value
      expect(taxCustomerIdInput).toHaveValue('existing-id')

      // Enable sync
      await user.click(syncCheckbox)

      // Tax customer ID should be cleared
      expect(taxCustomerIdInput).toHaveValue('')
    })

    it('THEN should not clear tax customer ID when sync is enabled in edition mode', async () => {
      const user = userEvent.setup()

      render(
        <TestAvalaraTaxProviderContentWrapper
          isEdition={true}
          selectedAvalaraIntegration={mockAvalaraIntegration}
          defaultValues={{
            ...emptyCreateCustomerDefaultValues,
            taxCustomer: {
              taxCustomerId: 'existing-id',
              syncWithProvider: false,
            },
          }}
        />,
      )

      const taxCustomerIdInput = screen.getByRole('textbox')
      const syncCheckbox = screen.getByRole('checkbox')

      // Input should have the existing value
      expect(taxCustomerIdInput).toHaveValue('existing-id')

      // Enable sync
      await user.click(syncCheckbox)

      // Tax customer ID should not be cleared in edition mode
      expect(taxCustomerIdInput).toHaveValue('existing-id')
    })
  })

  describe('WHEN component is disabled', () => {
    it('THEN should disable fields when hadInitialAvalaraIntegrationCustomer is true', () => {
      render(
        <TestAvalaraTaxProviderContentWrapper
          hadInitialAvalaraIntegrationCustomer={true}
          selectedAvalaraIntegration={mockAvalaraIntegration}
        />,
      )

      const taxCustomerIdInput = screen.getByRole('textbox')
      const syncCheckbox = screen.getByRole('checkbox')

      expect(taxCustomerIdInput).toBeDisabled()
      expect(syncCheckbox).toBeDisabled()
    })

    it('THEN should disable tax customer ID when sync is enabled', () => {
      render(
        <TestAvalaraTaxProviderContentWrapper
          selectedAvalaraIntegration={mockAvalaraIntegration}
          defaultValues={{
            ...emptyCreateCustomerDefaultValues,
            taxCustomer: {
              taxCustomerId: '',
              syncWithProvider: true,
            },
          }}
        />,
      )

      const taxCustomerIdInput = screen.getByRole('textbox')

      expect(taxCustomerIdInput).toBeDisabled()
    })
  })

  describe('WHEN rendering with checkbox label', () => {
    it('THEN should show correct label with integration name', () => {
      render(
        <TestAvalaraTaxProviderContentWrapper
          selectedAvalaraIntegration={mockAvalaraIntegration}
        />,
      )

      // The checkbox label should contain the integration name
      expect(screen.getByText(/Test Avalara Integration/)).toBeInTheDocument()
    })

    it('THEN should show default Avalara name when no integration provided', () => {
      render(<TestAvalaraTaxProviderContentWrapper />)

      // Should fall back to "Avalara" when no integration is provided
      // Use getAllByText since there might be multiple occurrences
      const avalaraElements = screen.getAllByText(/Avalara/)

      expect(avalaraElements.length).toBeGreaterThan(0)
    })
  })
})
