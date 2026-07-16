import { screen } from '@testing-library/react'

import { DEFAULT_BADGE_TEST_ID } from '~/components/paymentMethodSelection/PaymentMethodInfo'
import { formatPaymentMethodDetails } from '~/core/formats/formatPaymentMethodDetails'
import { ProviderTypeEnum } from '~/generated/graphql'
import { createMockPaymentMethod } from '~/hooks/customer/__tests__/factories/PaymentMethod.factory'
import { render } from '~/test-utils'

import { PaymentMethodDetailsCell } from '../PaymentMethodDetailsCell'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

describe('PaymentMethodDetailsCell', () => {
  describe('WHEN rendering payment method details', () => {
    it('THEN displays type, brand and last4 when all details are present', () => {
      const paymentMethod = createMockPaymentMethod({
        details: {
          __typename: 'PaymentMethodDetails',
          type: 'card',
          brand: 'visa',
          last4: '4242',
          expirationMonth: null,
          expirationYear: null,
        },
      })

      render(<PaymentMethodDetailsCell item={paymentMethod} />)

      const formattedDetails = formatPaymentMethodDetails(paymentMethod.details)

      expect(screen.getByText(formattedDetails)).toBeInTheDocument()
    })

    it('THEN displays expiration date chip when expiration month and year are present', () => {
      const paymentMethod = createMockPaymentMethod({
        details: {
          __typename: 'PaymentMethodDetails',
          type: 'card',
          brand: 'visa',
          last4: '4242',
          expirationMonth: '12',
          expirationYear: '2025',
        },
      })

      render(<PaymentMethodDetailsCell item={paymentMethod} />)

      expect(screen.getByText(/12\/2025/)).toBeInTheDocument()
    })

    it('THEN displays default badge when payment method is default', () => {
      const paymentMethod = createMockPaymentMethod({
        isDefault: true,
      })

      render(<PaymentMethodDetailsCell item={paymentMethod} />)

      const defaultBadge = screen.getByTestId(DEFAULT_BADGE_TEST_ID)

      expect(defaultBadge).toBeInTheDocument()
    })

    it('THEN displays payment provider type and id when both provider type and code are present', () => {
      const paymentMethod = createMockPaymentMethod({
        providerMethodId: 'pm_test_123',
        paymentProviderType: ProviderTypeEnum.Stripe,
      })

      render(<PaymentMethodDetailsCell item={paymentMethod} />)

      expect(screen.getByText('pm_test_123')).toBeInTheDocument()
    })
  })
})
