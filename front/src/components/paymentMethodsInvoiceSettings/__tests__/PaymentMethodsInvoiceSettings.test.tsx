import { screen } from '@testing-library/react'
import { FormikProps } from 'formik'

import { Customer } from '~/generated/graphql'
import { SubscriptionFormInput } from '~/pages/subscriptions/types'
import { render } from '~/test-utils'

import { PaymentMethodsInvoiceSettings } from '../PaymentMethodsInvoiceSettings'
import { ViewTypeEnum } from '../types'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
    locale: 'en',
  }),
}))

jest.mock('~/components/paymentMethodSelection/PaymentMethodSelection', () => ({
  PaymentMethodSelection: jest.fn(() => <div data-test="payment-method-selection" />),
}))

jest.mock('~/components/invoceCustomFooter/InvoceCustomFooter', () => ({
  InvoceCustomFooter: jest.fn(() => <div data-test="invoice-custom-footer" />),
}))

const mockFormikProps = {
  values: {
    paymentMethod: undefined,
  },
  setFieldValue: jest.fn(),
} as unknown as FormikProps<SubscriptionFormInput>

describe('PaymentMethodsInvoiceSettings', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('WHEN customer is null or undefined', () => {
    it('THEN returns null and does not render anything', () => {
      const { container } = render(
        <PaymentMethodsInvoiceSettings
          customer={null}
          form={mockFormikProps}
          viewType={ViewTypeEnum.Subscription}
        />,
      )

      expect(container.firstChild).toBeNull()
    })
  })

  describe('WHEN both customer.id and customer.externalId are null or undefined', () => {
    it('THEN returns null when both id and externalId are null', () => {
      const customer = {
        id: null,
        externalId: null,
      } as unknown as Customer

      const { container } = render(
        <PaymentMethodsInvoiceSettings
          customer={customer}
          form={mockFormikProps}
          viewType={ViewTypeEnum.Subscription}
        />,
      )

      expect(container.firstChild).toBeNull()
    })

    it('THEN returns null when both id and externalId are undefined', () => {
      const customer = {
        id: undefined,
        externalId: undefined,
      } as unknown as Customer

      const { container } = render(
        <PaymentMethodsInvoiceSettings
          customer={customer}
          form={mockFormikProps}
          viewType={ViewTypeEnum.Subscription}
        />,
      )

      expect(container.firstChild).toBeNull()
    })
  })

  describe('WHEN customer has valid id and externalId', () => {
    it('THEN renders both PaymentMethodSelection and InvoceCustomFooter', () => {
      const customer = {
        id: 'customer_id_123',
        externalId: 'customer_ext_123',
      } as Customer

      render(
        <PaymentMethodsInvoiceSettings
          customer={customer}
          form={mockFormikProps}
          viewType={ViewTypeEnum.Subscription}
        />,
      )

      expect(screen.getByTestId('payment-method-selection')).toBeInTheDocument()
      expect(screen.getByTestId('invoice-custom-footer')).toBeInTheDocument()
    })
  })

  describe('WHEN customer has only externalId', () => {
    it('THEN renders only PaymentMethodSelection', () => {
      const customer = {
        id: null,
        externalId: 'customer_ext_123',
      } as unknown as Customer

      render(
        <PaymentMethodsInvoiceSettings
          customer={customer}
          form={mockFormikProps}
          viewType={ViewTypeEnum.Subscription}
        />,
      )

      expect(screen.getByTestId('payment-method-selection')).toBeInTheDocument()
      expect(screen.queryByTestId('invoice-custom-footer')).not.toBeInTheDocument()
    })
  })

  describe('WHEN customer has only id', () => {
    it('THEN renders only InvoceCustomFooter', () => {
      const customer = {
        id: 'customer_id_123',
        externalId: null,
      } as unknown as Customer

      render(
        <PaymentMethodsInvoiceSettings
          customer={customer}
          form={mockFormikProps}
          viewType={ViewTypeEnum.Subscription}
        />,
      )

      expect(screen.queryByTestId('payment-method-selection')).not.toBeInTheDocument()
      expect(screen.getByTestId('invoice-custom-footer')).toBeInTheDocument()
    })

    it('THEN renders only InvoceCustomFooter when externalId is undefined', () => {
      const customer = {
        id: 'customer_id_123',
        externalId: undefined,
      } as unknown as Customer

      render(
        <PaymentMethodsInvoiceSettings
          customer={customer}
          form={mockFormikProps}
          viewType={ViewTypeEnum.Subscription}
        />,
      )

      expect(screen.queryByTestId('payment-method-selection')).not.toBeInTheDocument()
      expect(screen.getByTestId('invoice-custom-footer')).toBeInTheDocument()
    })
  })
})
