import { useAppForm } from '~/hooks/forms/useAppform'
import BillingFields from '~/pages/createCustomers/billingAccordion/BillingFields'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import { render } from '~/test-utils'

// Create a test wrapper component that properly initializes the form
const TestBillingFieldsWrapper = () => {
  const form = useAppForm({
    defaultValues: emptyCreateCustomerDefaultValues,
  })

  return <BillingFields form={form} fields="billingAddress" />
}

describe('BillingFields Integration Tests', () => {
  describe('WHEN rendering the component', () => {
    it('THEN should render without crashing', () => {
      const { container } = render(<TestBillingFieldsWrapper />)

      // Check for accordion content by checking that the component rendered
      expect(container.firstChild).toBeInTheDocument()
    })

    it('THEN should render a matching snapshot', () => {
      const rendered = render(<TestBillingFieldsWrapper />)

      expect(rendered.container).toMatchSnapshot()
    })
  })
})
