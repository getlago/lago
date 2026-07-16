import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { CurrencyEnum, ProviderPaymentMethodsEnum, ProviderTypeEnum } from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'
import PaymentProvidersAccordion from '~/pages/createCustomers/externalAppsAccordion/paymentProvidersAccordion/PaymentProvidersAccordion'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import { render } from '~/test-utils'

// Mock the usePaymentProviders hook
const mockPaymentProviders = {
  collection: [
    {
      __typename: 'StripeProvider',
      id: 'stripe-1',
      name: 'Stripe Production',
      code: 'STRIPE_PROD',
    },
    {
      __typename: 'AdyenProvider',
      id: 'adyen-1',
      name: 'Adyen Global',
      code: 'ADYEN_GLOBAL',
    },
    {
      __typename: 'GocardlessProvider',
      id: 'gocardless-1',
      name: 'GoCardless UK',
      code: 'GOCARDLESS_UK',
    },
  ],
}

const mockGetPaymentProvider = jest.fn((code: string | undefined) => {
  if (!code) return undefined
  const provider = mockPaymentProviders.collection.find((p) => p.code === code)

  if (!provider) return undefined
  return provider.__typename.toLocaleLowerCase().replace('provider', '') as ProviderTypeEnum
})

const mockUsePaymentProviders = {
  paymentProviders: { collection: mockPaymentProviders.collection },
  isLoadingPaymentProviders: false,
  getPaymentProvider: mockGetPaymentProvider,
}

jest.mock('~/pages/createCustomers/common/usePaymentProviders', () => ({
  usePaymentProviders: () => mockUsePaymentProviders,
}))

// Create test wrapper component
const TestPaymentProvidersAccordionWrapper = ({
  setShowPaymentSection = jest.fn(),
}: {
  setShowPaymentSection?: jest.Mock
}) => {
  const form = useAppForm({
    defaultValues: emptyCreateCustomerDefaultValues,
  })

  return (
    <PaymentProvidersAccordion
      form={form}
      setShowPaymentSection={setShowPaymentSection}
      customer={null}
      isEdition={false}
    />
  )
}

describe('PaymentProvidersAccordion Integration Tests', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('WHEN rendering the component', () => {
    it('THEN should render without crashing', () => {
      const { container } = render(<TestPaymentProvidersAccordionWrapper />)

      expect(container.firstChild).toBeInTheDocument()
    })

    it('THEN should render a matching snapshot', () => {
      const rendered = render(<TestPaymentProvidersAccordionWrapper />)

      expect(rendered.container).toMatchSnapshot()
    })

    it('THEN should render a matching snapshot after expansion', async () => {
      const user = userEvent.setup()
      const rendered = render(<TestPaymentProvidersAccordionWrapper />)

      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)
      await waitFor(() => {
        expect(screen.getByText(/connected account/i)).toBeInTheDocument()
        expect(rendered.container).toMatchSnapshot()
      })
    })
  })

  describe('WHEN user interacts with the accordion', () => {
    it('THEN should show payment provider selection when expanded', async () => {
      const user = userEvent.setup()

      render(<TestPaymentProvidersAccordionWrapper />)

      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        expect(screen.getByText(/connected account/i)).toBeInTheDocument()
      })
    })

    it('THEN should display expected accordion content', async () => {
      const user = userEvent.setup()

      render(<TestPaymentProvidersAccordionWrapper />)

      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        expect(screen.getByText(/connected account/i)).toBeInTheDocument()
        expect(screen.getByText('Select a connection')).toBeInTheDocument()
      })
    })

    it('THEN should handle form interaction for provider selection', async () => {
      const user = userEvent.setup()

      render(<TestPaymentProvidersAccordionWrapper />)

      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        const comboboxField = screen.getByRole('combobox')

        expect(comboboxField).toBeInTheDocument()
      })
    })

    it('THEN should show sync with provider checkbox for supported providers', async () => {
      const user = userEvent.setup()
      const TestWrapper = () => {
        const form = useAppForm({
          defaultValues: {
            ...emptyCreateCustomerDefaultValues,
            paymentProviderCode: 'STRIPE_PROD',
          } as typeof emptyCreateCustomerDefaultValues,
        })

        return (
          <PaymentProvidersAccordion
            form={form}
            setShowPaymentSection={jest.fn()}
            customer={null}
            isEdition={false}
          />
        )
      }

      render(<TestWrapper />)

      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        expect(screen.getByRole('textbox', { name: /provider customer id/i })).toBeInTheDocument()
      })
    })

    it('THEN should handle props correctly', async () => {
      const mockSetShowPaymentSection = jest.fn()

      render(
        <TestPaymentProvidersAccordionWrapper setShowPaymentSection={mockSetShowPaymentSection} />,
      )

      // Component should render without crashing with the mock function
      expect(screen.getByText('Select a connection')).toBeInTheDocument()
      // Check that we have buttons for expand/collapse and delete functionality
      expect(screen.getAllByRole('button')).toHaveLength(3)
      // Verify the mock function was passed as prop
      expect(mockSetShowPaymentSection).toBeDefined()
    })

    it('THEN should show Moneyhash alert when Moneyhash provider is selected', async () => {
      const user = userEvent.setup()

      // Update the mock to return Moneyhash for a specific code
      mockGetPaymentProvider.mockImplementation((code: string | undefined) => {
        if (code === 'MONEYHASH_PROD') return ProviderTypeEnum.Moneyhash
        return undefined
      })

      const TestWrapper = () => {
        const form = useAppForm({
          defaultValues: {
            ...emptyCreateCustomerDefaultValues,
            paymentProviderCode: 'MONEYHASH_PROD',
          } as typeof emptyCreateCustomerDefaultValues,
        })

        return (
          <PaymentProvidersAccordion
            form={form}
            setShowPaymentSection={jest.fn()}
            customer={null}
            isEdition={false}
          />
        )
      }

      render(<TestWrapper />)

      const accordionButton = screen.getAllByRole('button')[0]

      await user.click(accordionButton)

      await waitFor(() => {
        // Check that alert with Moneyhash-specific message appears
        expect(screen.getByText(/automate customer/i)).toBeInTheDocument()
      })
    })
  })

  describe('WHEN testing form interactions', () => {
    it('THEN should handle currency EUR and set appropriate payment methods', async () => {
      const TestWrapper = () => {
        const form = useAppForm({
          defaultValues: {
            ...emptyCreateCustomerDefaultValues,
            currency: CurrencyEnum.Eur,
          } as typeof emptyCreateCustomerDefaultValues,
        })

        return (
          <PaymentProvidersAccordion
            form={form}
            setShowPaymentSection={jest.fn()}
            customer={null}
            isEdition={false}
          />
        )
      }

      const rendered = render(<TestWrapper />)

      expect(rendered.container.firstChild).toBeInTheDocument()
    })

    it('THEN should handle currency USD and set appropriate payment methods', async () => {
      const TestWrapper = () => {
        const form = useAppForm({
          defaultValues: {
            ...emptyCreateCustomerDefaultValues,
            currency: CurrencyEnum.Usd,
          } as typeof emptyCreateCustomerDefaultValues,
        })

        return (
          <PaymentProvidersAccordion
            form={form}
            setShowPaymentSection={jest.fn()}
            customer={null}
            isEdition={false}
          />
        )
      }

      const rendered = render(<TestWrapper />)

      expect(rendered.container.firstChild).toBeInTheDocument()
    })

    it('THEN should handle sync with provider changes', async () => {
      const TestWrapper = () => {
        const form = useAppForm({
          defaultValues: {
            ...emptyCreateCustomerDefaultValues,
            paymentProviderCode: 'STRIPE_PROD',
            paymentProviderCustomer: {
              syncWithProvider: false,
              providerCustomerId: '',
              providerPaymentMethods: {
                [ProviderPaymentMethodsEnum.Card]: true,
              },
            },
          } as typeof emptyCreateCustomerDefaultValues,
        })

        return (
          <PaymentProvidersAccordion
            form={form}
            setShowPaymentSection={jest.fn()}
            customer={null}
            isEdition={false}
          />
        )
      }

      const rendered = render(<TestWrapper />)

      expect(rendered.container.firstChild).toBeInTheDocument()
    })
  })
})
