import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import {
  AddCustomerDrawerFragment,
  CountryCode,
  CustomerAccountTypeEnum,
  TimezoneEnum,
} from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'
import { BillingEntityOption } from '~/hooks/useBillingEntitiesOptions'
import CustomerInformation from '~/pages/createCustomers/customerInformation/CustomerInformation'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import { render } from '~/test-utils'

const MULTI_ENTITY_BILLING_FLAG = 'multi_entity_billing'
// The EU-tax banners render a design-system info alert. Their detailed
// display/business logic is covered in BillingEntityTaxAlerts.test.tsx; here we
// only assert the multi_entity_billing flag gate around that component.
const ALERT_INFO_TEST_ID = 'alert-type-info'

const mockHasFeatureFlag = jest.fn<boolean, [string]>(() => false)

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: {},
    hasFeatureFlag: mockHasFeatureFlag,
    timezoneConfig: { name: 'UTC', offset: '+00:00' },
    intlFormatDateTimeOrgaTZ: () => ({ date: '2026-01-01' }),
  }),
}))

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
  billingEntity: {
    __typename: 'BillingEntity',
    id: 'billing-entity-1',
    name: 'Test Billing Entity',
    code: 'TBE',
    // Customer's saved entity does NOT use EU tax management by default.
    euTaxManagement: false,
  },
}

// TBE → no EU tax; ABE → uses EU tax. Lets tests drive both banner cases.
const mockBillingEntities: BillingEntityOption[] = [
  {
    id: 'billing-entity-1',
    value: 'TBE',
    label: 'Test Billing Entity',
    name: 'Test Billing Entity',
    isDefault: true,
    euTaxManagement: false,
  },
  {
    id: 'billing-entity-2',
    value: 'ABE',
    label: 'Another Billing Entity',
    name: 'Another Billing Entity',
    isDefault: false,
    euTaxManagement: true,
  },
]

// Create a test wrapper component that properly initializes the form
const TestCustomerInformationWrapper = ({
  isEdition = false,
  customer = null,
  billingEntities = mockBillingEntities,
  isLoading = false,
  selectedBillingEntityCode,
}: {
  isEdition?: boolean
  customer?: AddCustomerDrawerFragment | null
  billingEntities?: BillingEntityOption[]
  isLoading?: boolean
  selectedBillingEntityCode?: string
}) => {
  const form = useAppForm({
    defaultValues: {
      ...emptyCreateCustomerDefaultValues,
      ...(selectedBillingEntityCode !== undefined
        ? { billingEntityCode: selectedBillingEntityCode }
        : {}),
    },
  })

  return (
    <CustomerInformation
      form={form}
      isEdition={isEdition}
      customer={customer}
      billingEntitiesList={billingEntities}
      isLoadingBillingEntities={isLoading}
    />
  )
}

const lockedCustomer: AddCustomerDrawerFragment = {
  ...mockCustomer,
  canEditAttributes: false,
}

describe('CustomerInformation Integration Tests', () => {
  beforeEach(() => {
    mockHasFeatureFlag.mockReset()
    mockHasFeatureFlag.mockReturnValue(false)
  })

  describe('WHEN rendering the component', () => {
    it('THEN should render without crashing', () => {
      const { container } = render(<TestCustomerInformationWrapper />)

      // Check for accordion content by checking that the component rendered
      expect(container.firstChild).toBeInTheDocument()
    })

    it('THEN should render a matching snapshot', () => {
      const rendered = render(<TestCustomerInformationWrapper />)

      expect(rendered.container).toMatchSnapshot()
    })

    it('THEN should render with edition mode', async () => {
      const user = userEvent.setup()
      const rendered = render(<TestCustomerInformationWrapper isEdition={true} />)

      const accordionButton = screen
        .getAllByRole('button')
        .find((btn) => !btn.hasAttribute('disabled')) as HTMLElement

      await user.click(accordionButton)
      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })

    it('THEN should render with customer data', async () => {
      const user = userEvent.setup()
      const rendered = render(
        <TestCustomerInformationWrapper customer={mockCustomer} isEdition={true} />,
      )
      const accordionButton = screen
        .getAllByRole('button')
        .find((btn) => !btn.hasAttribute('disabled')) as HTMLElement

      await user.click(accordionButton)
      await waitFor(() => {
        expect(rendered.container).toMatchSnapshot()
      })
    })
  })

  describe('WHEN editing a customer with non-editable attributes', () => {
    it('THEN keeps the billing entity field disabled when multi_entity_billing flag is OFF', () => {
      mockHasFeatureFlag.mockReturnValue(false)

      const { container } = render(
        <TestCustomerInformationWrapper customer={lockedCustomer} isEdition={true} />,
      )

      const billingEntityField = container.querySelector('input[name="billingEntityCode"]')

      expect(billingEntityField).not.toBeNull()

      expect(billingEntityField).toBeDisabled()
    })

    it('THEN enables the billing entity field when multi_entity_billing flag is ON', () => {
      mockHasFeatureFlag.mockImplementation((flag: string) => flag === MULTI_ENTITY_BILLING_FLAG)

      const { container } = render(
        <TestCustomerInformationWrapper customer={lockedCustomer} isEdition={true} />,
      )

      const billingEntityField = container.querySelector('input[name="billingEntityCode"]')

      expect(billingEntityField).not.toBeNull()

      expect(billingEntityField).toBeEnabled()
    })
  })

  describe('WHEN switching the billing entity (EU tax alert gate)', () => {
    it('THEN renders the EU-tax info alert under the multi_entity_billing flag', () => {
      mockHasFeatureFlag.mockImplementation((flag: string) => flag === MULTI_ENTITY_BILLING_FLAG)

      // Customer on TBE (EU tax OFF) switching to ABE (EU tax ON).
      render(
        <TestCustomerInformationWrapper
          customer={mockCustomer}
          isEdition={true}
          selectedBillingEntityCode="ABE"
        />,
      )

      expect(screen.getByTestId(ALERT_INFO_TEST_ID)).toBeInTheDocument()
    })

    it('THEN renders no EU-tax alert when the multi_entity_billing flag is OFF', () => {
      mockHasFeatureFlag.mockReturnValue(false)

      render(
        <TestCustomerInformationWrapper
          customer={mockCustomer}
          isEdition={true}
          selectedBillingEntityCode="ABE"
        />,
      )

      expect(screen.queryByTestId(ALERT_INFO_TEST_ID)).not.toBeInTheDocument()
    })
  })
})
