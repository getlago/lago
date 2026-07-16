import { screen } from '@testing-library/react'
import { ReactElement } from 'react'

import { Customer } from '~/generated/graphql'
import { render } from '~/test-utils'

import { PaymentMethodSettings } from '../PaymentMethodSettings'
import { PaymentMethodsForm, ViewTypeEnum } from '../types'

const mockPaymentMethodSelection = jest.fn<ReactElement, [Record<string, unknown>]>(() => (
  <div data-test="payment-method-selection" />
))

jest.mock('~/components/paymentMethodSelection/PaymentMethodSelection', () => ({
  PaymentMethodSelection: (props: Record<string, unknown>) => mockPaymentMethodSelection(props),
}))

const buildForm = (
  values: Record<string, unknown>,
): PaymentMethodsForm<ViewTypeEnum.Subscription> =>
  ({
    values,
    setFieldValue: jest.fn(),
  }) as unknown as PaymentMethodsForm<ViewTypeEnum.Subscription>

describe('PaymentMethodSettings', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('returns null when customer is null', () => {
    const { container } = render(
      <PaymentMethodSettings
        customer={null}
        form={buildForm({})}
        viewType={ViewTypeEnum.Subscription}
      />,
    )

    expect(container.firstChild).toBeNull()
    expect(mockPaymentMethodSelection).not.toHaveBeenCalled()
  })

  it('returns null when customer has no externalId', () => {
    const customer = { id: 'cust_1', externalId: null } as unknown as Customer

    const { container } = render(
      <PaymentMethodSettings
        customer={customer}
        form={buildForm({})}
        viewType={ViewTypeEnum.Subscription}
      />,
    )

    expect(container.firstChild).toBeNull()
    expect(mockPaymentMethodSelection).not.toHaveBeenCalled()
  })

  it('renders PaymentMethodSelection and forwards externalCustomerId + selected value', () => {
    const customer = { id: 'cust_1', externalId: 'ext_1' } as Customer
    const paymentMethod = { paymentMethodId: 'pm_1' }

    render(
      <PaymentMethodSettings
        customer={customer}
        form={buildForm({ paymentMethod })}
        viewType={ViewTypeEnum.Subscription}
      />,
    )

    expect(screen.getByTestId('payment-method-selection')).toBeInTheDocument()
    expect(mockPaymentMethodSelection).toHaveBeenCalledWith(
      expect.objectContaining({
        externalCustomerId: 'ext_1',
        viewType: ViewTypeEnum.Subscription,
        selectedPaymentMethod: paymentMethod,
      }),
    )
  })

  it('writes the paymentMethod field via setFieldValue', () => {
    const customer = { id: 'cust_1', externalId: 'ext_1' } as Customer
    const form = buildForm({})

    render(
      <PaymentMethodSettings
        customer={customer}
        form={form}
        viewType={ViewTypeEnum.Subscription}
      />,
    )

    const { setSelectedPaymentMethod } = mockPaymentMethodSelection.mock.calls[0][0] as {
      setSelectedPaymentMethod: (item: unknown) => void
    }
    const next = { paymentMethodId: 'pm_2' }

    setSelectedPaymentMethod(next)

    expect(form.setFieldValue).toHaveBeenCalledWith('paymentMethod', next)
  })

  it('respects formFieldBasePath for nested reads and writes', () => {
    const customer = { id: 'cust_1', externalId: 'ext_1' } as Customer
    const nested = { paymentMethodId: 'pm_nested' }
    const form = buildForm({ recurringTransactionRules: [{ paymentMethod: nested }] })

    render(
      <PaymentMethodSettings
        customer={customer}
        form={form}
        viewType={ViewTypeEnum.WalletRecurringTopUp}
        formFieldBasePath="recurringTransactionRules.0"
      />,
    )

    expect(mockPaymentMethodSelection).toHaveBeenCalledWith(
      expect.objectContaining({ selectedPaymentMethod: nested }),
    )

    const { setSelectedPaymentMethod } = mockPaymentMethodSelection.mock.calls[0][0] as {
      setSelectedPaymentMethod: (item: unknown) => void
    }
    const next = { paymentMethodId: 'pm_new' }

    setSelectedPaymentMethod(next)

    expect(form.setFieldValue).toHaveBeenCalledWith(
      'recurringTransactionRules.0.paymentMethod',
      next,
    )
  })
})
