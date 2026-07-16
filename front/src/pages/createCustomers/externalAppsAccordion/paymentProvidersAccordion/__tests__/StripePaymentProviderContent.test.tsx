import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { ProviderPaymentMethodsEnum } from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'
import StripePaymentProviderContent from '~/pages/createCustomers/externalAppsAccordion/paymentProvidersAccordion/StripePaymentProviderContent'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import { render } from '~/test-utils'

// Create a test wrapper component that properly initializes the form
const TestStripePaymentProviderContentWrapper = ({
  initialValues = {
    externalId: '',
    metadata: [],
  },
}: {
  initialValues?: Partial<typeof emptyCreateCustomerDefaultValues>
}) => {
  const form = useAppForm({
    defaultValues: {
      ...emptyCreateCustomerDefaultValues,
      paymentProviderCustomer: {
        providerCustomerId: '',
        syncWithProvider: false,
        providerPaymentMethods: {
          [ProviderPaymentMethodsEnum.Card]: true,
          [ProviderPaymentMethodsEnum.SepaDebit]: false,
          [ProviderPaymentMethodsEnum.Link]: false,
          [ProviderPaymentMethodsEnum.UsBankAccount]: false,
          [ProviderPaymentMethodsEnum.BacsDebit]: false,
          [ProviderPaymentMethodsEnum.CustomerBalance]: false,
          [ProviderPaymentMethodsEnum.Boleto]: false,
          [ProviderPaymentMethodsEnum.Crypto]: false,
        },
      },
      ...initialValues,
    } as typeof emptyCreateCustomerDefaultValues,
  })

  return <StripePaymentProviderContent form={form} />
}

describe('StripePaymentProviderContent Integration Tests', () => {
  describe('WHEN rendering the component', () => {
    it('THEN should render without crashing', async () => {
      const { container } = render(<TestStripePaymentProviderContentWrapper />)

      await waitFor(() => {
        expect(container.firstChild).toBeInTheDocument()
      })
    })

    it('THEN should render a matching snapshot', () => {
      const rendered = render(<TestStripePaymentProviderContentWrapper />)

      expect(rendered.container).toMatchSnapshot()
    })

    it('THEN should render payment method sections', () => {
      render(<TestStripePaymentProviderContentWrapper />)

      // Check for payment method sections
      expect(screen.getByText('Payment methods')).toBeInTheDocument()
      expect(screen.getByText(/general payment method/i)).toBeInTheDocument()
      expect(screen.getByText(/localized payment methods/i)).toBeInTheDocument()
    })

    it('THEN should render with customer balance enabled', () => {
      const rendered = render(
        <TestStripePaymentProviderContentWrapper
          initialValues={{
            paymentProviderCustomer: {
              providerCustomerId: '',
              syncWithProvider: false,
              providerPaymentMethods: {
                [ProviderPaymentMethodsEnum.CustomerBalance]: true,
                [ProviderPaymentMethodsEnum.Card]: false,
              },
            },
          }}
        />,
      )

      expect(rendered.container).toMatchSnapshot()
    })

    it('THEN should render with multiple payment methods enabled', () => {
      const rendered = render(
        <TestStripePaymentProviderContentWrapper
          initialValues={{
            paymentProviderCustomer: {
              providerCustomerId: '',
              syncWithProvider: false,
              providerPaymentMethods: {
                [ProviderPaymentMethodsEnum.Card]: true,
                [ProviderPaymentMethodsEnum.SepaDebit]: true,
                [ProviderPaymentMethodsEnum.Link]: true,
              },
            },
          }}
        />,
      )

      expect(rendered.container).toMatchSnapshot()
    })
  })

  describe('WHEN user interacts with payment method checkboxes', () => {
    it('THEN should handle card checkbox interactions', async () => {
      const user = userEvent.setup()

      render(<TestStripePaymentProviderContentWrapper />)

      const cardCheckbox = screen.getByRole('checkbox', { name: /card/i })

      expect(cardCheckbox).toBeChecked()

      await user.click(cardCheckbox)
      await waitFor(() => {
        expect(cardCheckbox).not.toBeChecked()
      })
    })

    it('THEN should handle link checkbox interactions', async () => {
      const user = userEvent.setup()

      render(<TestStripePaymentProviderContentWrapper />)

      const linkCheckbox = screen.getByRole('checkbox', { name: /link/i })

      expect(linkCheckbox).not.toBeChecked()

      await user.click(linkCheckbox)
      await waitFor(() => {
        expect(linkCheckbox).toBeChecked()
      })
    })

    it('THEN should handle SEPA Direct Debit checkbox interactions', async () => {
      const user = userEvent.setup()

      render(<TestStripePaymentProviderContentWrapper />)

      const sepaCheckbox = screen.getByRole('checkbox', { name: /sepa/i })

      expect(sepaCheckbox).not.toBeChecked()

      await user.click(sepaCheckbox)
      await waitFor(() => {
        expect(sepaCheckbox).toBeChecked()
      })
    })

    it('THEN should handle US Bank Account checkbox interactions', async () => {
      const user = userEvent.setup()

      render(<TestStripePaymentProviderContentWrapper />)

      const usBankCheckbox = screen.getByRole('checkbox', { name: /us bank account/i })

      expect(usBankCheckbox).not.toBeChecked()

      await user.click(usBankCheckbox)
      await waitFor(() => {
        expect(usBankCheckbox).toBeChecked()
      })
    })

    it('THEN should handle BACS Direct Debit checkbox interactions', async () => {
      const user = userEvent.setup()

      render(<TestStripePaymentProviderContentWrapper />)

      const bacsCheckbox = screen.getByRole('checkbox', { name: /bacs debit/i })

      expect(bacsCheckbox).not.toBeChecked()

      await user.click(bacsCheckbox)
      await waitFor(() => {
        expect(bacsCheckbox).toBeChecked()
      })
    })

    it('THEN should handle customer balance checkbox interactions', async () => {
      const user = userEvent.setup()

      render(<TestStripePaymentProviderContentWrapper />)

      const customerBalanceCheckbox = screen.getByRole('checkbox', { name: /bank transfers/i })

      expect(customerBalanceCheckbox).not.toBeChecked()

      await user.click(customerBalanceCheckbox)
      await waitFor(() => {
        expect(customerBalanceCheckbox).toBeChecked()
      })
    })

    it('THEN should handle Boleto checkbox interactions', async () => {
      const user = userEvent.setup()

      render(<TestStripePaymentProviderContentWrapper />)

      const boletoCheckbox = screen.getByRole('checkbox', { name: /boleto/i })

      expect(boletoCheckbox).not.toBeChecked()

      await user.click(boletoCheckbox)
      await waitFor(() => {
        expect(boletoCheckbox).toBeChecked()
      })
    })

    it('THEN should handle Crypto checkbox interactions', async () => {
      const user = userEvent.setup()

      render(<TestStripePaymentProviderContentWrapper />)

      const cryptoCheckbox = screen.getByRole('checkbox', { name: /crypto/i })

      expect(cryptoCheckbox).not.toBeChecked()

      await user.click(cryptoCheckbox)
      await waitFor(() => {
        expect(cryptoCheckbox).toBeChecked()
      })
    })
  })

  describe('WHEN testing payment method dependencies and business logic', () => {
    it('THEN should disable Link checkbox when Card is not enabled', async () => {
      render(
        <TestStripePaymentProviderContentWrapper
          initialValues={{
            paymentProviderCustomer: {
              providerCustomerId: '',
              syncWithProvider: false,
              providerPaymentMethods: {
                [ProviderPaymentMethodsEnum.Card]: false,
                [ProviderPaymentMethodsEnum.Link]: false,
              },
            },
          }}
        />,
      )

      const linkCheckbox = screen.getByRole('checkbox', { name: /link/i })

      expect(linkCheckbox).toBeDisabled()
    })

    it('THEN should disable other payment methods when customer balance is enabled', async () => {
      render(
        <TestStripePaymentProviderContentWrapper
          initialValues={{
            paymentProviderCustomer: {
              providerCustomerId: '',
              syncWithProvider: false,
              providerPaymentMethods: {
                [ProviderPaymentMethodsEnum.CustomerBalance]: true,
                [ProviderPaymentMethodsEnum.Card]: false,
              },
            },
          }}
        />,
      )

      const cardCheckbox = screen.getByRole('checkbox', { name: /card/i })
      const linkCheckbox = screen.getByRole('checkbox', { name: /link/i })
      const sepaCheckbox = screen.getByRole('checkbox', { name: /sepa/i })

      expect(cardCheckbox).toBeEnabled()
      expect(linkCheckbox).toBeDisabled()
      expect(sepaCheckbox).toBeDisabled()
    })

    it('THEN should handle unique payment method constraints', async () => {
      render(
        <TestStripePaymentProviderContentWrapper
          initialValues={{
            paymentProviderCustomer: {
              providerCustomerId: '',
              syncWithProvider: false,
              providerPaymentMethods: {
                [ProviderPaymentMethodsEnum.SepaDebit]: true,
                // Only SEPA enabled, making it unique
              },
            },
          }}
        />,
      )

      const sepaCheckbox = screen.getByRole('checkbox', { name: /sepa/i })

      expect(sepaCheckbox).toBeDisabled()
    })

    it('THEN should show info alert at the bottom', () => {
      render(<TestStripePaymentProviderContentWrapper />)

      // Check for informational text that appears at the bottom
      expect(
        screen.getByText(/customer must have at least one value selected/i),
      ).toBeInTheDocument()
    })

    it('THEN should handle form interactions correctly', async () => {
      const user = userEvent.setup()

      render(<TestStripePaymentProviderContentWrapper />)

      // Test multiple checkbox interactions in sequence
      const cardCheckbox = screen.getByRole('checkbox', { name: /card/i })
      const customerBalanceCheckbox = screen.getByRole('checkbox', { name: /bank transfers/i })

      // First uncheck card
      await user.click(cardCheckbox)
      await waitFor(() => {
        expect(cardCheckbox).not.toBeChecked()
      })

      // Then check card
      await user.click(cardCheckbox)
      await waitFor(() => {
        expect(cardCheckbox).toBeChecked()
      })

      // Then check customer balance
      await user.click(customerBalanceCheckbox)
      await waitFor(() => {
        expect(customerBalanceCheckbox).toBeChecked()
      })

      // Verify that card is still enabled but unchecked
      expect(cardCheckbox).toBeEnabled()
      expect(cardCheckbox).not.toBeChecked()

      // Then check card again
      await user.click(cardCheckbox)
      await waitFor(() => {
        expect(cardCheckbox).toBeChecked()
      })

      expect(customerBalanceCheckbox).toBeEnabled()
      expect(customerBalanceCheckbox).not.toBeChecked()
    })

    it('THEN should handle card unchecking and link dependency', async () => {
      const user = userEvent.setup()

      render(
        <TestStripePaymentProviderContentWrapper
          initialValues={{
            paymentProviderCustomer: {
              providerCustomerId: '',
              syncWithProvider: false,
              providerPaymentMethods: {
                [ProviderPaymentMethodsEnum.Card]: true,
                [ProviderPaymentMethodsEnum.Link]: true,
              },
            },
          }}
        />,
      )

      const cardCheckbox = screen.getByRole('checkbox', { name: /card/i })
      const linkCheckbox = screen.getByRole('checkbox', { name: /link/i })

      // Initially both should be checked
      expect(cardCheckbox).toBeChecked()
      expect(linkCheckbox).toBeChecked()

      // Uncheck card - this should also uncheck link
      await user.click(cardCheckbox)
      await waitFor(() => {
        expect(cardCheckbox).not.toBeChecked()
        expect(linkCheckbox).not.toBeChecked()
      })
    })
  })

  describe('WHEN testing edge cases and validation', () => {
    it('THEN should handle empty payment methods configuration', () => {
      render(
        <TestStripePaymentProviderContentWrapper
          initialValues={{
            paymentProviderCustomer: {
              providerCustomerId: '',
              syncWithProvider: false,
              providerPaymentMethods: {},
            },
          }}
        />,
      )

      // All checkboxes should be unchecked and not disabled
      const cardCheckbox = screen.getByRole('checkbox', { name: /card/i })

      expect(cardCheckbox).not.toBeChecked()
      expect(cardCheckbox).not.toBeDisabled()
    })

    it('THEN should render properly with undefined payment methods', () => {
      render(
        <TestStripePaymentProviderContentWrapper
          initialValues={{
            paymentProviderCustomer: {
              providerCustomerId: '',
              syncWithProvider: false,
              providerPaymentMethods: undefined,
            },
          }}
        />,
      )

      const cardCheckbox = screen.getByRole('checkbox', { name: /card/i })

      expect(cardCheckbox).toBeInTheDocument()
    })

    it('THEN should handle all payment methods enabled scenario', () => {
      const rendered = render(
        <TestStripePaymentProviderContentWrapper
          initialValues={{
            paymentProviderCustomer: {
              providerCustomerId: '',
              syncWithProvider: false,
              providerPaymentMethods: {
                [ProviderPaymentMethodsEnum.Card]: true,
                [ProviderPaymentMethodsEnum.Link]: true,
                [ProviderPaymentMethodsEnum.SepaDebit]: true,
                [ProviderPaymentMethodsEnum.UsBankAccount]: true,
                [ProviderPaymentMethodsEnum.BacsDebit]: true,
                [ProviderPaymentMethodsEnum.Boleto]: true,
                [ProviderPaymentMethodsEnum.Crypto]: true,
              },
            },
          }}
        />,
      )

      expect(rendered.container).toMatchSnapshot()
    })
  })
})
