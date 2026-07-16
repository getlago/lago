import { screen } from '@testing-library/react'

import { SelectedPaymentMethod } from '~/components/paymentMethodSelection/types'
import { PaymentMethodTypeEnum } from '~/generated/graphql'
import { createMockPaymentMethod } from '~/hooks/customer/__tests__/factories/PaymentMethod.factory'
import { render } from '~/test-utils'

import {
  INHERITED_BADGE_TEST_ID,
  MANUAL_PAYMENT_METHOD_TEST_ID,
  SubscriptionPaymentMethodDetails,
} from '../SubscriptionPaymentMethodDetails'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string, params?: Record<string, string>) => {
      if (params) return `${key}::${JSON.stringify(params)}`
      return key
    },
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    intlFormatDateTimeOrgaTZ: (dateStr: string) => ({
      date: `formatted-${dateStr}`,
      time: '',
      timezone: '',
    }),
    hasFeatureFlag: () => false,
  }),
}))

jest.mock('~/hooks/customer/usePaymentMethodsList', () => ({
  usePaymentMethodsList: jest.fn(() => ({ data: [], loading: false, error: false })),
}))

const { usePaymentMethodsList } = jest.requireMock('~/hooks/customer/usePaymentMethodsList')

describe('SubscriptionPaymentMethodDetails', () => {
  beforeEach(() => {
    ;(usePaymentMethodsList as jest.Mock).mockReturnValue({
      data: [],
      loading: false,
      error: false,
    })
  })

  it('shows manual fallback when type is Provider but no default exists', () => {
    const selectedPaymentMethod: SelectedPaymentMethod = {
      paymentMethodId: null,
      paymentMethodType: PaymentMethodTypeEnum.Provider,
    }

    render(<SubscriptionPaymentMethodDetails selectedPaymentMethod={selectedPaymentMethod} />)

    expect(screen.getByTestId(MANUAL_PAYMENT_METHOD_TEST_ID)).toBeInTheDocument()
  })

  it('renders the formatted payment method details when present', () => {
    const selectedPaymentMethod: SelectedPaymentMethod = {
      paymentMethodId: 'payment-method-id',
      paymentMethodType: PaymentMethodTypeEnum.Provider,
    }

    ;(usePaymentMethodsList as jest.Mock).mockReturnValue({
      data: [
        createMockPaymentMethod({
          id: 'payment-method-id',
          details: {
            __typename: 'PaymentMethodDetails',
            brand: 'visa',
            last4: '4242',
            type: 'card',
            expirationMonth: null,
            expirationYear: null,
          },
        }),
      ],
      loading: false,
      error: false,
    })

    render(<SubscriptionPaymentMethodDetails selectedPaymentMethod={selectedPaymentMethod} />)

    expect(screen.getByText(/Card - Visa •••• 4242/i)).toBeInTheDocument()
  })

  it('falls back to the createdAt date when the method has no metadata details', () => {
    const selectedPaymentMethod: SelectedPaymentMethod = {
      paymentMethodId: 'payment-method-no-details',
      paymentMethodType: PaymentMethodTypeEnum.Provider,
    }

    ;(usePaymentMethodsList as jest.Mock).mockReturnValue({
      data: [
        createMockPaymentMethod({
          id: 'payment-method-no-details',
          createdAt: '2024-01-15T10:00:00Z',
          details: {
            __typename: 'PaymentMethodDetails',
            brand: null,
            last4: null,
            type: null,
            expirationMonth: null,
            expirationYear: null,
          },
        }),
      ],
      loading: false,
      error: false,
    })

    render(<SubscriptionPaymentMethodDetails selectedPaymentMethod={selectedPaymentMethod} />)

    expect(screen.getByText(/formatted-2024-01-15T10:00:00Z/)).toBeInTheDocument()
  })

  it('renders the manual payment method type', () => {
    const selectedPaymentMethod: SelectedPaymentMethod = {
      paymentMethodId: null,
      paymentMethodType: PaymentMethodTypeEnum.Manual,
    }

    render(<SubscriptionPaymentMethodDetails selectedPaymentMethod={selectedPaymentMethod} />)

    expect(screen.getByTestId(MANUAL_PAYMENT_METHOD_TEST_ID)).toBeInTheDocument()
  })

  it('shows the inherited badge when using the customer default method', () => {
    ;(usePaymentMethodsList as jest.Mock).mockReturnValue({
      data: [
        createMockPaymentMethod({
          id: 'default-pm-id',
          isDefault: true,
          details: {
            __typename: 'PaymentMethodDetails',
            brand: 'visa',
            last4: '4242',
            type: 'card',
            expirationMonth: null,
            expirationYear: null,
          },
        }),
      ],
      loading: false,
      error: false,
    })

    render(
      <SubscriptionPaymentMethodDetails
        selectedPaymentMethod={{
          paymentMethodId: null,
          paymentMethodType: PaymentMethodTypeEnum.Provider,
        }}
        externalCustomerId="customer-external-id"
      />,
    )

    expect(screen.getByText(/Card - Visa •••• 4242/i)).toBeInTheDocument()
    expect(screen.getByTestId(INHERITED_BADGE_TEST_ID)).toBeInTheDocument()
  })

  it('shows the inherited badge when manual is inherited', () => {
    render(
      <SubscriptionPaymentMethodDetails
        selectedPaymentMethod={{
          paymentMethodId: null,
          paymentMethodType: PaymentMethodTypeEnum.Provider,
        }}
        externalCustomerId="customer-external-id"
      />,
    )

    expect(screen.getByTestId(MANUAL_PAYMENT_METHOD_TEST_ID)).toBeInTheDocument()
    expect(screen.getByTestId(INHERITED_BADGE_TEST_ID)).toBeInTheDocument()
  })
})
