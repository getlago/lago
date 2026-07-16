import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import {
  CustomerInvoiceBalancesLegacyCards,
  OVERDUE_INVOICES_ALERT_TEST_ID,
} from '../CustomerInvoiceBalancesLegacyCards'

const mockHasPermissions = jest.fn(() => true)
const mockIsCustomerReadyForOverduePayment = jest.fn(() => true)
const mockNavigateFn = jest.fn()

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: jest.fn(() => ({
    organization: { defaultCurrency: 'USD' as const },
    intlFormatDateTimeOrgaTZ: jest.fn(() => ({
      time: '12:00:00',
      date: '2024-01-01',
    })),
  })),
}))

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useParams: jest.fn(() => ({ customerId: 'cust-123' })),
  generatePath: jest.fn((route: string, params: { customerId: string }) =>
    route.replace(':customerId', params.customerId),
  ),
}))

jest.mock('~/core/router', () => ({
  ...jest.requireActual('~/core/router'),
  useNavigate: jest.fn(() => mockNavigateFn),
  CUSTOMER_REQUEST_OVERDUE_PAYMENT_ROUTE: '/customers/:customerId/request-overdue-payment',
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: jest.fn(() => ({
    hasPermissions: mockHasPermissions,
  })),
}))

jest.mock('~/hooks/useIsCustomerReadyForOverduePayment', () => ({
  useIsCustomerReadyForOverduePayment: jest.fn(() => ({
    isCustomerReadyForOverduePayment: mockIsCustomerReadyForOverduePayment(),
    loading: false,
    error: undefined,
  })),
}))

const defaultOverdueBalances = [
  {
    amountCents: '50000',
    currency: CurrencyEnum.Usd,
    lagoInvoiceIds: ['inv-1', 'inv-2'],
    billingEntityId: null,
  },
]

const defaultGrossRevenues = [
  {
    amountCents: '100000',
    currency: CurrencyEnum.Usd,
    invoicesCount: '5',
    month: '2024-01',
    billingEntityId: null,
  },
]

const defaultProps = {
  currency: CurrencyEnum.Usd,
  grossRevenues: defaultGrossRevenues,
  grossRevenuesLoading: false,
  grossRevenuesError: undefined,
  overdueBalances: defaultOverdueBalances,
  overdueBalancesLoading: false,
  overdueBalancesError: undefined,
  lastPaymentRequestCreatedAt: undefined,
  refreshOverdueBalances: jest.fn(),
}

describe('CustomerInvoiceBalancesLegacyCards', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockHasPermissions.mockReturnValue(true)
    mockIsCustomerReadyForOverduePayment.mockReturnValue(true)
  })

  describe('GIVEN analytics permissions are granted', () => {
    describe('WHEN gross revenue and overdue data are available', () => {
      it('THEN should render both the gross revenue and overdue cards', () => {
        render(<CustomerInvoiceBalancesLegacyCards {...defaultProps} />)

        // The component renders two OverviewCard instances when permissions are granted.
        // OverviewCard renders the title via translate, so we look for the translation keys.
        // Gross revenue title key
        expect(screen.getByText('text_6553885df387fd0097fd7385')).toBeInTheDocument()
        // Overdue balance title key
        expect(screen.getByText('text_6670a7222702d70114cc795a')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN customer has overdue invoices and is ready for payment', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should show the overdue alert', () => {
        render(<CustomerInvoiceBalancesLegacyCards {...defaultProps} />)

        expect(screen.getByTestId(OVERDUE_INVOICES_ALERT_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN customer has no overdue invoices', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should not show the overdue alert', () => {
        render(
          <CustomerInvoiceBalancesLegacyCards
            {...defaultProps}
            overdueBalances={[
              {
                amountCents: '0',
                currency: CurrencyEnum.Usd,
                lagoInvoiceIds: [],
                billingEntityId: null,
              },
            ]}
          />,
        )

        expect(screen.queryByTestId(OVERDUE_INVOICES_ALERT_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN customer is not ready for overdue payment', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should not show the overdue alert', () => {
        mockIsCustomerReadyForOverduePayment.mockReturnValue(false)

        render(<CustomerInvoiceBalancesLegacyCards {...defaultProps} />)

        expect(screen.queryByTestId(OVERDUE_INVOICES_ALERT_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN analyticsView permission is denied', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should not render the cards', () => {
        mockHasPermissions.mockReturnValue(false)

        render(<CustomerInvoiceBalancesLegacyCards {...defaultProps} />)

        expect(screen.queryByText('text_6553885df387fd0097fd7385')).not.toBeInTheDocument()
        expect(screen.queryByText('text_6670a7222702d70114cc795a')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the overdue alert is displayed with a request payment button', () => {
    describe('WHEN the request payment button is clicked', () => {
      it('THEN should navigate to the overdue payment route', async () => {
        render(<CustomerInvoiceBalancesLegacyCards {...defaultProps} />)

        const alert = screen.getByTestId(OVERDUE_INVOICES_ALERT_TEST_ID)

        // The Alert renders a button with the translate key as label
        const button = alert.querySelector('button')

        expect(button).not.toBeNull()
        await userEvent.click(button as HTMLButtonElement)

        expect(mockNavigateFn).toHaveBeenCalledWith('/customers/cust-123/request-overdue-payment')
      })
    })
  })
})
