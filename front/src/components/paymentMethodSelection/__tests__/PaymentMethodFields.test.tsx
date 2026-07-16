import { fireEvent, screen, within } from '@testing-library/react'
import { useState } from 'react'

import { PaymentMethodTypeEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { ViewTypeEnum } from '../../paymentMethodsInvoiceSettings/types'
import {
  PaymentMethodFields,
  PM_FIELDS_FALLBACK_RADIO_TEST_ID,
  PM_FIELDS_MANUAL_RADIO_TEST_ID,
  PM_FIELDS_SPECIFIC_RADIO_TEST_ID,
} from '../PaymentMethodFields'
import { SelectedPaymentMethod } from '../types'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key, locale: 'en' }),
}))

const mockComboboxProps: { current: Record<string, unknown> | null } = { current: null }

jest.mock('../PaymentMethodComboBox', () => ({
  PaymentMethodComboBox: (props: Record<string, unknown>) => {
    mockComboboxProps.current = props

    return <div data-test="pm-combobox" />
  },
}))

const clickRadio = (testId: string): void => {
  fireEvent.click(within(screen.getByTestId(testId)).getByRole('radio'))
}

describe('PaymentMethodFields', () => {
  const baseProps = {
    viewType: ViewTypeEnum.Subscription,
    externalCustomerId: 'ext_1',
  }

  beforeEach(() => {
    mockComboboxProps.current = null
  })

  it('seeds FALLBACK behavior when no value is set (no combobox)', () => {
    render(<PaymentMethodFields {...baseProps} value={undefined} onChange={jest.fn()} />)

    expect(screen.queryByTestId('pm-combobox')).not.toBeInTheDocument()
  })

  it('seeds SPECIFIC behavior when a specific method is set and shows the combobox', () => {
    const value: SelectedPaymentMethod = {
      paymentMethodId: 'pm_1',
      paymentMethodType: PaymentMethodTypeEnum.Provider,
    }

    render(<PaymentMethodFields {...baseProps} value={value} onChange={jest.fn()} />)

    expect(screen.getByTestId('pm-combobox')).toBeInTheDocument()
    // Popper renders at the dialog layer (z 2000) so it stays above whichever
    // overlay (dialog or drawer) hosts the fields.
    expect(mockComboboxProps.current?.PopperProps).toEqual({ displayInDialog: true })
  })

  it('forwards the validation error to the combobox', () => {
    const value: SelectedPaymentMethod = {
      paymentMethodId: 'pm_1',
      paymentMethodType: PaymentMethodTypeEnum.Provider,
    }

    render(<PaymentMethodFields {...baseProps} value={value} onChange={jest.fn()} error="boom" />)

    expect(mockComboboxProps.current?.error).toBe('boom')
  })

  it('seeds MANUAL behavior when the method type is manual (no combobox)', () => {
    const value: SelectedPaymentMethod = {
      paymentMethodId: null,
      paymentMethodType: PaymentMethodTypeEnum.Manual,
    }

    render(<PaymentMethodFields {...baseProps} value={value} onChange={jest.fn()} />)

    expect(screen.queryByTestId('pm-combobox')).not.toBeInTheDocument()
  })

  it('emits a manual selection when MANUAL is picked', () => {
    const onChange = jest.fn()

    render(<PaymentMethodFields {...baseProps} value={undefined} onChange={onChange} />)
    clickRadio(PM_FIELDS_MANUAL_RADIO_TEST_ID)

    expect(onChange).toHaveBeenCalledWith({
      paymentMethodId: null,
      paymentMethodType: PaymentMethodTypeEnum.Manual,
    })
  })

  it('emits a fallback selection when FALLBACK is picked', () => {
    const onChange = jest.fn()
    const value: SelectedPaymentMethod = {
      paymentMethodId: null,
      paymentMethodType: PaymentMethodTypeEnum.Manual,
    }

    render(<PaymentMethodFields {...baseProps} value={value} onChange={onChange} />)
    clickRadio(PM_FIELDS_FALLBACK_RADIO_TEST_ID)

    expect(onChange).toHaveBeenCalledWith({
      paymentMethodId: null,
      paymentMethodType: PaymentMethodTypeEnum.Provider,
    })
  })

  it('emits a specific (provider) selection with no method when SPECIFIC is picked', () => {
    const onChange = jest.fn()

    render(<PaymentMethodFields {...baseProps} value={undefined} onChange={onChange} />)
    clickRadio(PM_FIELDS_SPECIFIC_RADIO_TEST_ID)

    expect(onChange).toHaveBeenCalledWith({
      paymentMethodId: undefined,
      paymentMethodType: PaymentMethodTypeEnum.Provider,
    })
  })

  it('forwards a combobox pick as a specific provider selection', () => {
    const onChange = jest.fn()
    const value: SelectedPaymentMethod = {
      paymentMethodId: 'pm_1',
      paymentMethodType: PaymentMethodTypeEnum.Provider,
    }

    render(<PaymentMethodFields {...baseProps} value={value} onChange={onChange} />)

    const setSelected = mockComboboxProps.current?.setSelectedPaymentMethod as (
      v: SelectedPaymentMethod,
    ) => void

    setSelected({ paymentMethodId: 'pm_2', paymentMethodType: PaymentMethodTypeEnum.Provider })

    expect(onChange).toHaveBeenCalledWith({
      paymentMethodId: 'pm_2',
      paymentMethodType: PaymentMethodTypeEnum.Provider,
    })
  })

  it('keeps the picked method across a FALLBACK round-trip back to SPECIFIC', () => {
    const onChange = jest.fn()

    // Reactive harness: mirrors the drawer wiring where each onChange feeds back
    // into `value`. The picked method id is tracked locally so switching
    // SPECIFIC -> FALLBACK -> SPECIFIC restores it.
    const Harness = () => {
      const [value, setValue] = useState<SelectedPaymentMethod>({
        paymentMethodId: 'pm_1',
        paymentMethodType: PaymentMethodTypeEnum.Provider,
      })

      return (
        <PaymentMethodFields
          {...baseProps}
          value={value}
          onChange={(next) => {
            onChange(next)
            setValue(next)
          }}
        />
      )
    }

    render(<Harness />)
    clickRadio(PM_FIELDS_FALLBACK_RADIO_TEST_ID)
    onChange.mockClear()
    clickRadio(PM_FIELDS_SPECIFIC_RADIO_TEST_ID)

    expect(onChange).toHaveBeenLastCalledWith({
      paymentMethodId: 'pm_1',
      paymentMethodType: PaymentMethodTypeEnum.Provider,
    })
  })

  it('reports the behavior changes through onBehaviorChange', () => {
    const onBehaviorChange = jest.fn()

    render(
      <PaymentMethodFields
        {...baseProps}
        value={undefined}
        onChange={jest.fn()}
        onBehaviorChange={onBehaviorChange}
      />,
    )

    clickRadio(PM_FIELDS_MANUAL_RADIO_TEST_ID)

    expect(onBehaviorChange).toHaveBeenCalledWith('manual')
  })
})
