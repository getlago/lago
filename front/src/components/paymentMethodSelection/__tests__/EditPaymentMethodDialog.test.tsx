import { act, cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { ViewTypeEnum } from '~/components/paymentMethodsInvoiceSettings/types'
import { PaymentMethodTypeEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import {
  EDIT_PM_DIALOG_SAVE_BUTTON_TEST_ID,
  EditPaymentMethodDialog,
} from '../EditPaymentMethodDialog'
import { PaymentMethodBehavior, SelectedPaymentMethod } from '../types'

// The selector content is unit-tested in PaymentMethodFields.test; here we only
// verify the dialog shell: seeding the draft, committing it on save, the guard.
const mockFieldsProps: {
  current: {
    value?: SelectedPaymentMethod
    onChange: (v: SelectedPaymentMethod) => void
    onBehaviorChange?: (b: PaymentMethodBehavior) => void
  } | null
} = { current: null }

jest.mock('../PaymentMethodFields', () => ({
  PaymentMethodFields: (props: {
    value?: SelectedPaymentMethod
    onChange: (v: SelectedPaymentMethod) => void
    onBehaviorChange?: (b: PaymentMethodBehavior) => void
  }) => {
    mockFieldsProps.current = props

    return <div data-test="payment-method-fields" />
  },
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key, locale: 'en' }),
}))

function prepare({
  open = true,
  selectedPaymentMethod = undefined,
  onSave = jest.fn(),
  onClose = jest.fn(),
}: {
  open?: boolean
  selectedPaymentMethod?: SelectedPaymentMethod
  onSave?: jest.Mock
  onClose?: jest.Mock
} = {}) {
  render(
    <EditPaymentMethodDialog
      open={open}
      onClose={onClose}
      externalCustomerId="ext_1"
      selectedPaymentMethod={selectedPaymentMethod}
      setSelectedPaymentMethod={onSave}
      viewType={ViewTypeEnum.Subscription}
    />,
  )

  return { onSave, onClose }
}

describe('EditPaymentMethodDialog', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
    mockFieldsProps.current = null
  })

  it('seeds the shared fields with the current selection on open', async () => {
    const selectedPaymentMethod = {
      paymentMethodId: 'pm_1',
      paymentMethodType: PaymentMethodTypeEnum.Provider,
    }

    await act(() => prepare({ selectedPaymentMethod }))

    expect(screen.getByTestId('payment-method-fields')).toBeInTheDocument()
    expect(mockFieldsProps.current?.value).toEqual(selectedPaymentMethod)
  })

  it('commits the edited draft on save and closes', async () => {
    const user = userEvent.setup()
    const { onSave, onClose } = await act(() => prepare())

    const manual = { paymentMethodId: null, paymentMethodType: PaymentMethodTypeEnum.Manual }

    act(() => {
      mockFieldsProps.current?.onBehaviorChange?.(PaymentMethodBehavior.MANUAL)
      mockFieldsProps.current?.onChange(manual)
    })

    await user.click(screen.getByTestId(EDIT_PM_DIALOG_SAVE_BUTTON_TEST_ID))

    expect(onSave).toHaveBeenCalledWith(manual)
    expect(onClose).toHaveBeenCalledTimes(1)
  })

  it('disables save when "specific" is picked without a method', async () => {
    await act(() => prepare())

    act(() => {
      mockFieldsProps.current?.onBehaviorChange?.(PaymentMethodBehavior.SPECIFIC)
      mockFieldsProps.current?.onChange({
        paymentMethodId: undefined,
        paymentMethodType: PaymentMethodTypeEnum.Provider,
      })
    })

    expect(screen.getByTestId(EDIT_PM_DIALOG_SAVE_BUTTON_TEST_ID)).toBeDisabled()
  })
})
