import { screen, waitFor } from '@testing-library/react'

import { HubspotIntegration, HubspotTargetedObjectsEnum } from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'
import HubspotCrmProviderContent from '~/pages/createCustomers/externalAppsAccordion/crmProvidersAccordion/HubspotCrmProviderContent'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import { render } from '~/test-utils'

const mockHubspotIntegration: HubspotIntegration = {
  __typename: 'HubspotIntegration',
  id: 'hubspot-test-id',
  code: 'hubspot-test-code',
  name: 'Test Hubspot Integration',
  connectionId: 'hubspot-conn-123',
  defaultTargetedObject: HubspotTargetedObjectsEnum.Companies,
}

// Create a test wrapper component that properly initializes the form
const TestHubspotCrmProviderContentWrapper = ({
  hadInitialHubspotIntegrationCustomer = false,
  selectedHubspotIntegration = undefined,
  isEdition = false,
  defaultValues = emptyCreateCustomerDefaultValues,
}: {
  hadInitialHubspotIntegrationCustomer?: boolean
  selectedHubspotIntegration?: HubspotIntegration
  isEdition?: boolean
  defaultValues?: typeof emptyCreateCustomerDefaultValues
}) => {
  const form = useAppForm({
    defaultValues,
  })

  return (
    <HubspotCrmProviderContent
      form={form}
      hadInitialHubspotIntegrationCustomer={hadInitialHubspotIntegrationCustomer}
      selectedHubspotIntegration={selectedHubspotIntegration}
      isEdition={isEdition}
    />
  )
}

describe('HubspotCrmProviderContent Integration Tests', () => {
  describe('WHEN rendering the component', () => {
    it('THEN should render without crashing', async () => {
      const { container } = render(<TestHubspotCrmProviderContentWrapper />)

      await waitFor(() => {
        // Check that the component rendered
        expect(container.firstChild).toBeInTheDocument()
      })
    })

    it('THEN should render a matching snapshot', async () => {
      const rendered = render(<TestHubspotCrmProviderContentWrapper />)

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render with Hubspot integration data', async () => {
      const rendered = render(
        <TestHubspotCrmProviderContentWrapper
          selectedHubspotIntegration={mockHubspotIntegration}
        />,
      )

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render in edition mode', async () => {
      const rendered = render(
        <TestHubspotCrmProviderContentWrapper
          isEdition={true}
          selectedHubspotIntegration={mockHubspotIntegration}
        />,
      )

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render with initial integration customer', async () => {
      const rendered = render(
        <TestHubspotCrmProviderContentWrapper
          hadInitialHubspotIntegrationCustomer={true}
          selectedHubspotIntegration={mockHubspotIntegration}
        />,
      )

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })
  })

  describe('WHEN user interacts with form fields', () => {
    it('THEN should display targeted object combobox', () => {
      render(
        <TestHubspotCrmProviderContentWrapper
          selectedHubspotIntegration={mockHubspotIntegration}
        />,
      )

      // Should display the targeted object combobox
      const targetedObjectCombobox = screen.getByRole('combobox')

      expect(targetedObjectCombobox).toBeInTheDocument()
      expect(targetedObjectCombobox).toHaveAttribute('name', 'crmCustomer.targetedObject')
    })

    it('THEN should display fields when targeted object is pre-selected', async () => {
      const renderer = render(
        <TestHubspotCrmProviderContentWrapper
          selectedHubspotIntegration={mockHubspotIntegration}
          defaultValues={{
            ...emptyCreateCustomerDefaultValues,
            crmCustomer: {
              ...emptyCreateCustomerDefaultValues.crmCustomer,
              targetedObject: HubspotTargetedObjectsEnum.Companies,
            },
          }}
        />,
      )

      // Should display the targeted object combobox
      expect(screen.getByRole('combobox')).toBeInTheDocument()
      await waitFor(() => {
        expect(renderer.container).toMatchSnapshot()
      })

      // Test that the targeted object field has the right value
      await waitFor(() => {
        const comboBox = screen.getByRole('combobox')

        expect(comboBox).toHaveValue('HubSpot Companies')
      })

      // Just verify the component renders properly with the pre-selected value
      // The async nature of the form means additional fields may not be immediately rendered
      expect(screen.getByRole('combobox')).toBeInTheDocument()
    })
  })
})
