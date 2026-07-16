import { cleanup, screen } from '@testing-library/react'

import { ProviderTypeEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { PaymentProviderChip } from '../PaymentProviderChip'

describe('PaymentProviderChip', () => {
  afterEach(cleanup)

  describe('WHEN paymentProvider is undefined', () => {
    it('THEN should return null', () => {
      const { container } = render(<PaymentProviderChip paymentProvider={undefined} />)

      expect(container.firstChild).toBeNull()
    })
  })

  describe('WHEN rendering a payment provider', () => {
    it('THEN should render Stripe provider with icon and translated label', () => {
      render(<PaymentProviderChip paymentProvider={ProviderTypeEnum.Stripe} />)

      // Check that the component renders
      expect(screen.getByText('Stripe')).toBeInTheDocument()
    })
  })

  describe('WHEN rendering manual payment provider', () => {
    it('THEN should render manual with receipt icon and short label', () => {
      render(<PaymentProviderChip paymentProvider="manual" />)

      expect(screen.getByText('Manual')).toBeInTheDocument()
    })

    it('THEN should render manual_long with receipt icon and long label', () => {
      render(<PaymentProviderChip paymentProvider="manual_long" />)

      expect(screen.getByText('Manual payment')).toBeInTheDocument()
    })
  })

  describe('WHEN custom label is provided', () => {
    it('THEN should use custom label instead of default translated label', () => {
      render(
        <PaymentProviderChip
          paymentProvider={ProviderTypeEnum.Stripe}
          label="Custom Stripe Label"
        />,
      )

      expect(screen.getByText('Custom Stripe Label')).toBeInTheDocument()
      expect(screen.queryByText('Stripe')).not.toBeInTheDocument()
    })
  })
})
