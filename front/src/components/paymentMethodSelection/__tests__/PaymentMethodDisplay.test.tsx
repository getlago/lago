import { screen } from '@testing-library/react'

import { createMockPaymentMethod } from '~/hooks/customer/__tests__/factories/PaymentMethod.factory'
import { render } from '~/test-utils'

import {
  INHERITED_BADGE_TEST_ID,
  MANUAL_PAYMENT_METHOD_TEST_ID,
  PaymentMethodDisplay,
} from '../PaymentMethodDisplay'
import { DisplayedPaymentMethod } from '../useDisplayedPaymentMethod'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
    locale: 'en',
  }),
}))

describe('PaymentMethodDisplay', () => {
  describe('WHEN isManual is true', () => {
    it('THEN displays manual payment method text with inherited badge when isInherited is true', () => {
      const displayedPaymentMethod: DisplayedPaymentMethod = {
        paymentMethod: null,
        isManual: true,
        isInherited: true,
      }

      render(<PaymentMethodDisplay displayedPaymentMethod={displayedPaymentMethod} />)

      expect(screen.getByTestId(MANUAL_PAYMENT_METHOD_TEST_ID)).toBeInTheDocument()
      expect(screen.getByTestId(INHERITED_BADGE_TEST_ID)).toBeInTheDocument()
    })

    it('THEN displays manual payment method text without inherited badge when isInherited is false', () => {
      const displayedPaymentMethod: DisplayedPaymentMethod = {
        paymentMethod: null,
        isManual: true,
        isInherited: false,
      }

      render(<PaymentMethodDisplay displayedPaymentMethod={displayedPaymentMethod} />)

      expect(screen.getByTestId(MANUAL_PAYMENT_METHOD_TEST_ID)).toBeInTheDocument()
      expect(screen.queryByTestId(INHERITED_BADGE_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('WHEN paymentMethod is provided', () => {
    it('THEN displays PaymentMethodDetails with inherited badge when isInherited is true', () => {
      const paymentMethod = createMockPaymentMethod({
        id: 'pm_001',
        isDefault: true,
        details: {
          __typename: 'PaymentMethodDetails',
          brand: 'visa',
          last4: '4242',
          type: 'card',
          expirationMonth: '12',
          expirationYear: '2025',
        },
      })

      const displayedPaymentMethod: DisplayedPaymentMethod = {
        paymentMethod,
        isManual: false,
        isInherited: true,
      }

      render(<PaymentMethodDisplay displayedPaymentMethod={displayedPaymentMethod} />)

      expect(screen.getByText(/visa/i)).toBeInTheDocument()
      expect(screen.getByText(/4242/i)).toBeInTheDocument()
      expect(screen.getByTestId(INHERITED_BADGE_TEST_ID)).toBeInTheDocument()
    })

    it('THEN displays PaymentMethodDetails without inherited badge when isInherited is false', () => {
      const paymentMethod = createMockPaymentMethod({
        id: 'pm_001',
        isDefault: false,
        details: {
          __typename: 'PaymentMethodDetails',
          brand: 'mastercard',
          last4: '8888',
          type: 'card',
          expirationMonth: '06',
          expirationYear: '2026',
        },
      })

      const displayedPaymentMethod: DisplayedPaymentMethod = {
        paymentMethod,
        isManual: false,
        isInherited: false,
      }

      render(<PaymentMethodDisplay displayedPaymentMethod={displayedPaymentMethod} />)

      expect(screen.getByText(/mastercard/i)).toBeInTheDocument()
      expect(screen.getByText(/8888/i)).toBeInTheDocument()
      expect(screen.queryByTestId(INHERITED_BADGE_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('WHEN paymentMethod is null and isManual is false', () => {
    it('THEN returns null', () => {
      const displayedPaymentMethod: DisplayedPaymentMethod = {
        paymentMethod: null,
        isManual: false,
        isInherited: false,
      }

      const { container } = render(
        <PaymentMethodDisplay displayedPaymentMethod={displayedPaymentMethod} />,
      )

      expect(container.firstChild).toBeNull()
    })
  })
})
