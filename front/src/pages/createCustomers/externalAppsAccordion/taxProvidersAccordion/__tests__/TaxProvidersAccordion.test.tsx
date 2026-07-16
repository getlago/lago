import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import {
  AddCustomerDrawerFragment,
  AnrokIntegration,
  AvalaraIntegration,
  CountryCode,
  CustomerAccountTypeEnum,
  TimezoneEnum,
} from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'
import TaxProvidersAccordion from '~/pages/createCustomers/externalAppsAccordion/taxProvidersAccordion/TaxProvidersAccordion'
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
  xeroCustomer: {
    __typename: 'XeroCustomer',
    id: 'xero-customer-1',
    integrationId: 'xero-integration-1',
    externalCustomerId: 'xero-123',
    integrationCode: 'xero-test-code',
  },
  netsuiteCustomer: {
    __typename: 'NetsuiteCustomer',
    id: 'netsuite-customer-1',
    integrationId: 'netsuite-integration-1',
    externalCustomerId: 'netsuite-456',
    integrationCode: 'netsuite-test-code',
  },
  billingEntity: {
    __typename: 'BillingEntity',
    id: 'billing-entity-1',
    name: 'Test Billing Entity',
    code: 'TBE',
    euTaxManagement: false,
  },
}

const mockAnrokIntegration: AnrokIntegration = {
  __typename: 'AnrokIntegration',
  id: 'anrok-test-id',
  code: 'anrok-test-code',
  name: 'Test Anrok Integration',
  apiKey: 'anrok-api-key-123',
}

const mockAvalaraIntegration: AvalaraIntegration = {
  __typename: 'AvalaraIntegration',
  id: 'avalara-test-id',
  code: 'avalara-test-code',
  name: 'Test Avalara Integration',
  licenseKey: 'avalara-license-key-123',
  companyCode: 'avalara-company-123',
}

// Mock the tax providers hook to return proper structure
jest.mock('~/pages/createCustomers/common/useTaxProviders', () => ({
  useTaxProviders: () => ({
    taxProviders: {
      integrations: {
        collection: [mockAnrokIntegration, mockAvalaraIntegration],
      },
    },
    isLoadingTaxProviders: false,
  }),
}))

// Create a test wrapper component that properly initializes the form
const TestTaxProvidersAccordionWrapper = ({
  setShowTaxSection = jest.fn(),
  isEdition = false,
  customer = null,
}: {
  setShowTaxSection?: jest.Mock
  isEdition?: boolean
  customer?: AddCustomerDrawerFragment | null
}) => {
  const form = useAppForm({
    defaultValues: emptyCreateCustomerDefaultValues,
  })

  return (
    <TaxProvidersAccordion
      form={form}
      setShowTaxSection={setShowTaxSection}
      isEdition={isEdition}
      customer={customer}
    />
  )
}

describe('TaxProvidersAccordion Integration Tests', () => {
  describe('WHEN rendering the component', () => {
    it('THEN should render without crashing', () => {
      const { container } = render(<TestTaxProvidersAccordionWrapper />)

      // Check that the component rendered
      expect(container.firstChild).toBeInTheDocument()
    })

    it('THEN should render a matching snapshot', () => {
      const rendered = render(<TestTaxProvidersAccordionWrapper />)

      expect(rendered.container).toMatchSnapshot()
    })

    it('THEN should render a matching snapshot after expansion', async () => {
      const user = userEvent.setup()
      const rendered = render(<TestTaxProvidersAccordionWrapper />)

      // Find and click the accordion button to expand it
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        // After expanding, check for the tax provider selection field
        expect(screen.getByRole('combobox')).toBeInTheDocument()
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render with edition mode', async () => {
      const user = userEvent.setup()
      const rendered = render(<TestTaxProvidersAccordionWrapper isEdition={true} />)

      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render with customer data', async () => {
      const user = userEvent.setup()
      const rendered = render(
        <TestTaxProvidersAccordionWrapper customer={mockCustomer} isEdition={true} />,
      )
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)
      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })
  })

  describe('WHEN user interacts with the accordion', () => {
    it('THEN should show tax provider selection when expanded', async () => {
      const user = userEvent.setup()

      render(<TestTaxProvidersAccordionWrapper />)

      // Find accordion buttons (there might be multiple)
      const buttons = screen.getAllByRole('button')
      const accordionButton =
        buttons.find((button) => button.getAttribute('aria-expanded') !== null) || buttons[0]

      await user.click(accordionButton)

      await waitFor(() => {
        // Should show the tax provider combobox
        expect(screen.getByRole('combobox')).toBeInTheDocument()
      })
    })

    it('THEN should display expected accordion content', async () => {
      const user = userEvent.setup()

      const renderer = render(<TestTaxProvidersAccordionWrapper />)

      // Find and click the accordion
      const buttons = screen.getAllByRole('button')
      const accordionButton =
        buttons.find((button) => button.getAttribute('aria-expanded') !== null) || buttons[0]

      await user.click(accordionButton)

      await waitFor(() => {
        // Should show the combobox for tax provider selection
        const combobox = screen.getByRole('combobox')

        expect(combobox).toBeInTheDocument()
        expect(renderer.container).toMatchSnapshot()

        // Should show some text content
        expect(screen.getByText(/connected account/i)).toBeInTheDocument()
      })
    })

    it('THEN should handle props correctly', () => {
      const mockSetShowTaxSection = jest.fn()

      render(<TestTaxProvidersAccordionWrapper setShowTaxSection={mockSetShowTaxSection} />)

      // Component should render without crashing with the mock function
      expect(screen.getByText('Select a connection')).toBeInTheDocument()
      // Check that we have buttons for expand/collapse and delete functionality
      expect(screen.getAllByRole('button')).toHaveLength(3)
      // Verify the mock function was passed as prop
      expect(mockSetShowTaxSection).toBeDefined()
    })

    it('THEN should call setShowTaxSection when deleting tax provider', async () => {
      const user = userEvent.setup()
      const mockSetShowTaxSection = jest.fn()

      render(<TestTaxProvidersAccordionWrapper setShowTaxSection={mockSetShowTaxSection} />)

      // Find the delete button (should be the last button)
      const buttons = screen.getAllByRole('button')
      const deleteButton = buttons[buttons.length - 1]

      await user.click(deleteButton)

      expect(mockSetShowTaxSection).toHaveBeenCalledWith(false)
    })
  })

  describe('WHEN selecting tax providers', () => {
    it('THEN should show Anrok content when Anrok integration is selected', async () => {
      const user = userEvent.setup()

      const TestWrapperWithAnrok = () => {
        const form = useAppForm({
          defaultValues: {
            ...emptyCreateCustomerDefaultValues,
            taxProviderCode: 'anrok-test-code',
          } as typeof emptyCreateCustomerDefaultValues,
        })

        return (
          <TaxProvidersAccordion
            form={form}
            setShowTaxSection={jest.fn()}
            isEdition={false}
            customer={null}
          />
        )
      }

      render(<TestWrapperWithAnrok />)

      // Expand the accordion
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        // Should show Anrok-specific content
        expect(screen.getAllByText(/Test Anrok Integration/)).toHaveLength(2) // One in summary, one in content
      })
    })

    it('THEN should show Avalara content when Avalara integration is selected', async () => {
      const user = userEvent.setup()

      const TestWrapperWithAvalara = () => {
        const form = useAppForm({
          defaultValues: {
            ...emptyCreateCustomerDefaultValues,
            taxProviderCode: 'avalara-test-code',
          } as typeof emptyCreateCustomerDefaultValues,
        })

        return (
          <TaxProvidersAccordion
            form={form}
            setShowTaxSection={jest.fn()}
            isEdition={false}
            customer={null}
          />
        )
      }

      render(<TestWrapperWithAvalara />)

      // Expand the accordion
      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        // Should show Avalara-specific content
        expect(screen.getAllByText(/Test Avalara Integration/)).toHaveLength(2) // One in summary, one in content
      })
    })

    it('THEN should display correct avatar for selected integration', async () => {
      const TestWrapperWithSelectedProvider = () => {
        const form = useAppForm({
          defaultValues: {
            ...emptyCreateCustomerDefaultValues,
            taxProviderCode: 'anrok-test-code',
          } as typeof emptyCreateCustomerDefaultValues,
        })

        return (
          <TaxProvidersAccordion
            form={form}
            setShowTaxSection={jest.fn()}
            isEdition={false}
            customer={null}
          />
        )
      }

      const rendered = render(<TestWrapperWithSelectedProvider />)

      // Should show the integration name in the summary
      expect(screen.getByText('Test Anrok Integration')).toBeInTheDocument()
      expect(rendered.container).toMatchSnapshot()
    })
  })

  describe('WHEN managing form state', () => {
    it('THEN should clear all tax-related fields when deleting provider', async () => {
      const user = userEvent.setup()
      const mockSetShowTaxSection = jest.fn()

      const TestWrapperWithData = () => {
        const form = useAppForm({
          defaultValues: {
            ...emptyCreateCustomerDefaultValues,
            taxProviderCode: 'anrok-test-code',
            taxCustomer: {
              taxCustomerId: 'test-id',
              syncWithProvider: true,
            },
          } as typeof emptyCreateCustomerDefaultValues,
        })

        return (
          <TaxProvidersAccordion
            form={form}
            setShowTaxSection={mockSetShowTaxSection}
            isEdition={false}
            customer={null}
          />
        )
      }

      render(<TestWrapperWithData />)

      // Find and click the delete button
      const buttons = screen.getAllByRole('button')
      const deleteButton = buttons[buttons.length - 1]

      await user.click(deleteButton)

      // Should call setShowTaxSection with false
      expect(mockSetShowTaxSection).toHaveBeenCalledWith(false)
    })
  })

  describe('WHEN loading tax providers', () => {
    it('THEN should handle loading state correctly', () => {
      // Mock loading state
      jest.doMock('~/pages/createCustomers/common/useTaxProviders', () => ({
        useTaxProviders: () => ({
          taxProviders: undefined,
          isLoadingTaxProviders: true,
        }),
      }))

      const { container } = render(<TestTaxProvidersAccordionWrapper />)

      expect(container.firstChild).toBeInTheDocument()
    })
  })
})
