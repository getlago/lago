import { screen } from '@testing-library/react'

import { formatPaymentMethodDetails } from '~/core/formats/formatPaymentMethodDetails'
import { ProviderTypeEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { DEFAULT_BADGE_TEST_ID, PaymentMethodInfo } from '../PaymentMethodInfo'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => {
      if (key === 'text_17440321235444hcxi31f8j6') return 'Default'
      if (key === 'text_1762437511802zhw5mx0iamd') return 'Exp'
      if (key === 'text_62b1edddbf5f461ab971277d') return 'Stripe'
      return key
    },
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    intlFormatDateTimeOrgaTZ: (date: string) => ({
      date: new Date(date).toLocaleDateString(),
      time: '',
      timezone: 'UTC',
    }),
  }),
}))

const mockDetails = {
  type: 'card',
  brand: 'visa',
  last4: '4242',
  expirationMonth: '12',
  expirationYear: '2025',
}

const createMockPaymentMethod = (
  overrides: Partial<{
    createdAt: string
    details: typeof mockDetails | null
    isDefault: boolean
    paymentProviderType: ProviderTypeEnum | null
    paymentProviderName: string | null
    providerMethodId: string
  }> = {},
) => ({
  createdAt: '2024-01-15T10:00:00Z',
  details: mockDetails,
  isDefault: false,
  paymentProviderType: null as ProviderTypeEnum | null,
  paymentProviderName: null as string | null,
  providerMethodId: 'pm_test_001',
  ...overrides,
})

describe('PaymentMethodInfo', () => {
  describe('WHEN rendering with payment method details', () => {
    it('THEN displays formatted payment method details', () => {
      render(
        <PaymentMethodInfo
          paymentMethod={createMockPaymentMethod()}
          showExpiration
          showProviderAvatar
        />,
      )

      const formattedDetails = formatPaymentMethodDetails(mockDetails)

      expect(screen.getByText(formattedDetails)).toBeInTheDocument()
    })

    it('THEN displays expiration date chip when showExpiration is true', () => {
      render(
        <PaymentMethodInfo
          paymentMethod={createMockPaymentMethod()}
          showExpiration
          showProviderAvatar
        />,
      )

      expect(screen.getByText(/12\/2025/)).toBeInTheDocument()
    })

    it('THEN hides expiration date chip when showExpiration is false', () => {
      render(
        <PaymentMethodInfo
          paymentMethod={createMockPaymentMethod()}
          showExpiration={false}
          showProviderAvatar
        />,
      )

      expect(screen.queryByText(/12\/2025/)).not.toBeInTheDocument()
    })

    it('THEN displays default badge when isDefault is true', () => {
      render(
        <PaymentMethodInfo
          paymentMethod={createMockPaymentMethod({ isDefault: true })}
          showExpiration
          showProviderAvatar
        />,
      )

      const defaultBadge = screen.getByTestId(DEFAULT_BADGE_TEST_ID)

      expect(defaultBadge).toBeInTheDocument()
    })

    it('THEN does not display default badge when isDefault is false', () => {
      render(
        <PaymentMethodInfo
          paymentMethod={createMockPaymentMethod({ isDefault: false })}
          showExpiration
          showProviderAvatar
        />,
      )

      expect(screen.queryByTestId(DEFAULT_BADGE_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('WHEN rendering with PSP info', () => {
    it('THEN displays payment provider chip when paymentProviderType is provided', () => {
      render(
        <PaymentMethodInfo
          paymentMethod={createMockPaymentMethod({ paymentProviderType: ProviderTypeEnum.Stripe })}
          showExpiration
          showProviderAvatar
        />,
      )

      expect(screen.getByText('Stripe')).toBeInTheDocument()
    })

    it('THEN displays providerMethodId when providerMethodId is provided', () => {
      render(
        <PaymentMethodInfo
          paymentMethod={createMockPaymentMethod({
            providerMethodId: 'pm_test_123',
            paymentProviderType: ProviderTypeEnum.Stripe,
          })}
          showExpiration
          showProviderAvatar
        />,
      )

      expect(screen.getByText('pm_test_123')).toBeInTheDocument()
    })

    it('THEN displays separator dot when both paymentProviderType and providerMethodId are provided', () => {
      const { container } = render(
        <PaymentMethodInfo
          paymentMethod={createMockPaymentMethod({
            providerMethodId: 'pm_test_123',
            paymentProviderType: ProviderTypeEnum.Stripe,
          })}
          showExpiration
          showProviderAvatar
        />,
      )

      // The PSP info container is the second child inside the main container (first is PaymentMethodDetails)
      const mainContainer = container.querySelector('.flex.flex-1.flex-col')
      const pspInfoContainer = mainContainer?.children[1]

      expect(pspInfoContainer?.textContent).toContain('•')
      expect(pspInfoContainer?.textContent).toContain('Stripe')
      expect(pspInfoContainer?.textContent).toContain('pm_test_123')
    })

    it('THEN does not display separator dot when only providerMethodId is provided without paymentProviderType', () => {
      render(
        <PaymentMethodInfo
          paymentMethod={createMockPaymentMethod({ providerMethodId: 'pm_test_123' })}
          showExpiration
          showProviderAvatar
        />,
      )

      expect(screen.queryByText(' • ')).not.toBeInTheDocument()
    })
  })

  describe('WHEN controlling provider avatar visibility', () => {
    it('THEN shows provider avatar when showProviderAvatar is true', () => {
      render(
        <PaymentMethodInfo
          paymentMethod={createMockPaymentMethod({ paymentProviderType: ProviderTypeEnum.Stripe })}
          showExpiration
          showProviderAvatar
        />,
      )

      // Avatar has data-test="connector/small"
      const avatar = screen.getByTestId('connector/small')

      expect(avatar).toBeInTheDocument()
    })

    it('THEN hides provider avatar when showProviderAvatar is false', () => {
      render(
        <PaymentMethodInfo
          paymentMethod={createMockPaymentMethod({ paymentProviderType: ProviderTypeEnum.Stripe })}
          showExpiration
          showProviderAvatar={false}
        />,
      )

      // Avatar should not be present
      expect(screen.queryByTestId('connector/small')).not.toBeInTheDocument()
    })
  })
})
