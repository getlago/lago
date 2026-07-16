import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { AnrokIntegration } from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'
import AnrokTaxProviderContent from '~/pages/createCustomers/externalAppsAccordion/taxProvidersAccordion/AnrokTaxProviderContent'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import { render } from '~/test-utils'

const mockAnrokIntegration: AnrokIntegration = {
  __typename: 'AnrokIntegration',
  id: 'anrok-test-id',
  code: 'anrok-test-code',
  name: 'Test Anrok Integration',
  apiKey: 'anrok-api-key-123',
}

// Create a test wrapper component that properly initializes the form
const TestAnrokTaxProviderContentWrapper = ({
  hadInitialAnrokIntegrationCustomer = false,
  selectedAnrokIntegration = undefined,
  isEdition = false,
  defaultValues = emptyCreateCustomerDefaultValues,
}: {
  hadInitialAnrokIntegrationCustomer?: boolean
  selectedAnrokIntegration?: AnrokIntegration
  isEdition?: boolean
  defaultValues?: typeof emptyCreateCustomerDefaultValues
}) => {
  const form = useAppForm({
    defaultValues,
  })

  return (
    <AnrokTaxProviderContent
      form={form}
      hadInitialAnrokIntegrationCustomer={hadInitialAnrokIntegrationCustomer}
      selectedAnrokIntegration={selectedAnrokIntegration}
      isEdition={isEdition}
    />
  )
}

describe('AnrokTaxProviderContent Integration Tests', () => {
  describe('WHEN rendering the component', () => {
    it('THEN should render without crashing', async () => {
      const { container } = render(<TestAnrokTaxProviderContentWrapper />)

      // Check that the component rendered
      await waitFor(() => {
        expect(container.firstChild).toBeInTheDocument()
      })
    })

    it('THEN should render a matching snapshot', async () => {
      const rendered = render(<TestAnrokTaxProviderContentWrapper />)

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render with Anrok integration data', async () => {
      const rendered = render(
        <TestAnrokTaxProviderContentWrapper selectedAnrokIntegration={mockAnrokIntegration} />,
      )

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render in edition mode', async () => {
      const rendered = render(
        <TestAnrokTaxProviderContentWrapper
          isEdition={true}
          selectedAnrokIntegration={mockAnrokIntegration}
        />,
      )

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render with initial integration customer', async () => {
      const rendered = render(
        <TestAnrokTaxProviderContentWrapper
          hadInitialAnrokIntegrationCustomer={true}
          selectedAnrokIntegration={mockAnrokIntegration}
        />,
      )

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })
  })

  describe('WHEN user interacts with form fields', () => {
    it('THEN should display tax customer ID field', () => {
      render(<TestAnrokTaxProviderContentWrapper selectedAnrokIntegration={mockAnrokIntegration} />)

      // Should have the tax customer ID text input
      const taxCustomerIdInput = screen.getByRole('textbox')

      expect(taxCustomerIdInput).toBeInTheDocument()
      expect(taxCustomerIdInput).toHaveAttribute('name', 'taxCustomer.taxCustomerId')
    })

    it('THEN should display sync with provider checkbox', () => {
      render(<TestAnrokTaxProviderContentWrapper selectedAnrokIntegration={mockAnrokIntegration} />)

      // Should have the sync checkbox
      const syncCheckbox = screen.getByRole('checkbox')

      expect(syncCheckbox).toBeInTheDocument()
      // Checkbox doesn't have a name attribute in this implementation, but it should be present
      expect(syncCheckbox).toHaveAttribute('aria-labelledby')
    })

    it('THEN should handle user input in tax customer ID field', async () => {
      const user = userEvent.setup()

      render(<TestAnrokTaxProviderContentWrapper selectedAnrokIntegration={mockAnrokIntegration} />)

      const taxCustomerIdInput = screen.getByRole('textbox')

      await user.type(taxCustomerIdInput, 'anrok-customer-456')

      expect(taxCustomerIdInput).toHaveValue('anrok-customer-456')
    })

    it('THEN should handle sync checkbox toggle', async () => {
      const user = userEvent.setup()

      render(<TestAnrokTaxProviderContentWrapper selectedAnrokIntegration={mockAnrokIntegration} />)

      const syncCheckbox = screen.getByRole('checkbox')

      expect(syncCheckbox).not.toBeChecked()

      await user.click(syncCheckbox)
      expect(syncCheckbox).toBeChecked()
    })

    it('THEN should disable tax customer ID when sync is enabled', async () => {
      const user = userEvent.setup()

      render(<TestAnrokTaxProviderContentWrapper selectedAnrokIntegration={mockAnrokIntegration} />)

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
        <TestAnrokTaxProviderContentWrapper
          selectedAnrokIntegration={mockAnrokIntegration}
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
        <TestAnrokTaxProviderContentWrapper
          isEdition={true}
          selectedAnrokIntegration={mockAnrokIntegration}
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
    it('THEN should disable fields when hadInitialAnrokIntegrationCustomer is true', () => {
      render(
        <TestAnrokTaxProviderContentWrapper
          hadInitialAnrokIntegrationCustomer={true}
          selectedAnrokIntegration={mockAnrokIntegration}
        />,
      )

      const taxCustomerIdInput = screen.getByRole('textbox')
      const syncCheckbox = screen.getByRole('checkbox')

      expect(taxCustomerIdInput).toBeDisabled()
      expect(syncCheckbox).toBeDisabled()
    })

    it('THEN should disable tax customer ID when sync is enabled', () => {
      render(
        <TestAnrokTaxProviderContentWrapper
          selectedAnrokIntegration={mockAnrokIntegration}
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
      render(<TestAnrokTaxProviderContentWrapper selectedAnrokIntegration={mockAnrokIntegration} />)

      // The checkbox label should contain the integration name
      expect(screen.getByText(/Test Anrok Integration/)).toBeInTheDocument()
    })

    it('THEN should show default Anrok name when no integration provided', () => {
      render(<TestAnrokTaxProviderContentWrapper />)

      // Should fall back to "Anrok" when no integration is provided
      // Use getAllByText since there might be multiple occurrences
      const anrokElements = screen.getAllByText(/Anrok/)

      expect(anrokElements.length).toBeGreaterThan(0)
    })
  })
})
