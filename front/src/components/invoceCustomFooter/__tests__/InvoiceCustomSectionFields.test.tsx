import { fireEvent, screen, within } from '@testing-library/react'
import { useState } from 'react'

import { render } from '~/test-utils'

import { ViewTypeEnum } from '../../paymentMethodsInvoiceSettings/types'
import {
  ICS_FIELDS_APPLY_RADIO_TEST_ID,
  ICS_FIELDS_CUSTOMER_DEFAULT_CHIPS_TEST_ID,
  ICS_FIELDS_FALLBACK_RADIO_TEST_ID,
  ICS_FIELDS_NONE_RADIO_TEST_ID,
  InvoiceCustomSectionFields,
} from '../InvoiceCustomSectionFields'
import { InvoiceCustomSectionInput } from '../types'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key, locale: 'en' }),
}))

jest.mock('~/hooks/useInvoiceCustomSections', () => ({
  useInvoiceCustomSections: () => ({
    data: [
      { id: 'cs_1', name: 'Bank details' },
      { id: 'cs_2', name: 'Legal footer' },
    ],
    loading: false,
  }),
}))

jest.mock('~/hooks/useCustomerInvoiceCustomSections', () => ({
  useCustomerInvoiceCustomSections: () => ({
    data: {
      configurableInvoiceCustomSections: [{ id: 'cs_default', name: 'Customer default' }],
      skipInvoiceCustomSections: false,
    },
    loading: false,
    error: false,
    customer: null,
  }),
}))

const mockComboboxProps: { current: Record<string, unknown> | null } = { current: null }

jest.mock('~/components/form', () => ({
  MultipleComboBox: (props: Record<string, unknown>) => {
    mockComboboxProps.current = props

    return <div data-test="ics-combobox" />
  },
}))

const clickRadio = (testId: string): void => {
  fireEvent.click(within(screen.getByTestId(testId)).getByRole('radio'))
}

describe('InvoiceCustomSectionFields', () => {
  const baseProps = {
    viewType: ViewTypeEnum.Subscription,
    customerId: 'cust_1',
  }

  it('seeds FALLBACK behavior when no value is set and shows the customer-default display', () => {
    render(<InvoiceCustomSectionFields {...baseProps} value={undefined} onChange={jest.fn()} />)

    expect(screen.getByTestId(ICS_FIELDS_CUSTOMER_DEFAULT_CHIPS_TEST_ID)).toBeInTheDocument()
    expect(screen.queryByTestId('ics-combobox')).not.toBeInTheDocument()
  })

  it('seeds APPLY behavior when specific sections are set and shows the combobox', () => {
    const value: InvoiceCustomSectionInput = {
      invoiceCustomSections: [{ id: 'cs_1', name: 'Bank details' }],
      skipInvoiceCustomSections: false,
    }

    render(<InvoiceCustomSectionFields {...baseProps} value={value} onChange={jest.fn()} />)

    expect(screen.getByTestId('ics-combobox')).toBeInTheDocument()
    expect(screen.queryByTestId(ICS_FIELDS_CUSTOMER_DEFAULT_CHIPS_TEST_ID)).not.toBeInTheDocument()
    // Popper renders at the dialog layer (z 2000) so it stays above whichever
    // overlay (dialog or drawer) hosts the fields.
    expect(mockComboboxProps.current?.PopperProps).toEqual({ displayInDialog: true })
  })

  it('forwards the validation error to the combobox', () => {
    const value: InvoiceCustomSectionInput = {
      invoiceCustomSections: [{ id: 'cs_1', name: 'Bank details' }],
      skipInvoiceCustomSections: false,
    }

    render(
      <InvoiceCustomSectionFields {...baseProps} value={value} onChange={jest.fn()} error="boom" />,
    )

    expect(mockComboboxProps.current?.error).toBe('boom')
  })

  it('seeds NONE behavior when sections are skipped (no display, no combobox)', () => {
    const value: InvoiceCustomSectionInput = {
      invoiceCustomSections: [],
      skipInvoiceCustomSections: true,
    }

    render(<InvoiceCustomSectionFields {...baseProps} value={value} onChange={jest.fn()} />)

    expect(screen.queryByTestId(ICS_FIELDS_CUSTOMER_DEFAULT_CHIPS_TEST_ID)).not.toBeInTheDocument()
    expect(screen.queryByTestId('ics-combobox')).not.toBeInTheDocument()
  })

  it('hides the customer-default display when switching away from fallback', () => {
    render(<InvoiceCustomSectionFields {...baseProps} value={undefined} onChange={jest.fn()} />)

    expect(screen.getByTestId(ICS_FIELDS_CUSTOMER_DEFAULT_CHIPS_TEST_ID)).toBeInTheDocument()

    clickRadio(ICS_FIELDS_APPLY_RADIO_TEST_ID)
    expect(screen.queryByTestId(ICS_FIELDS_CUSTOMER_DEFAULT_CHIPS_TEST_ID)).not.toBeInTheDocument()

    clickRadio(ICS_FIELDS_NONE_RADIO_TEST_ID)
    expect(screen.queryByTestId(ICS_FIELDS_CUSTOMER_DEFAULT_CHIPS_TEST_ID)).not.toBeInTheDocument()
  })

  it('emits a skip selection when NONE is picked', () => {
    const onChange = jest.fn()

    render(<InvoiceCustomSectionFields {...baseProps} value={undefined} onChange={onChange} />)
    clickRadio(ICS_FIELDS_NONE_RADIO_TEST_ID)

    expect(onChange).toHaveBeenCalledWith({
      invoiceCustomSections: [],
      skipInvoiceCustomSections: true,
    })
  })

  it('emits a fallback selection when FALLBACK is picked', () => {
    const onChange = jest.fn()
    const value: InvoiceCustomSectionInput = {
      invoiceCustomSections: [],
      skipInvoiceCustomSections: true,
    }

    render(<InvoiceCustomSectionFields {...baseProps} value={value} onChange={onChange} />)
    clickRadio(ICS_FIELDS_FALLBACK_RADIO_TEST_ID)

    expect(onChange).toHaveBeenCalledWith({
      invoiceCustomSections: [],
      skipInvoiceCustomSections: false,
    })
  })

  it('keeps already-selected sections across a NONE round-trip back to APPLY', () => {
    const onChange = jest.fn()

    // Reactive harness: mirrors the drawer wiring where each onChange feeds back
    // into `value`. Without local section state, switching APPLY -> NONE -> APPLY
    // would lose the selection (NONE empties the fed-back value).
    const Harness = () => {
      const [value, setValue] = useState<InvoiceCustomSectionInput>({
        invoiceCustomSections: [{ id: 'cs_1', name: 'Bank details' }],
        skipInvoiceCustomSections: false,
      })

      return (
        <InvoiceCustomSectionFields
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
    clickRadio(ICS_FIELDS_NONE_RADIO_TEST_ID)
    onChange.mockClear()
    clickRadio(ICS_FIELDS_APPLY_RADIO_TEST_ID)

    expect(onChange).toHaveBeenLastCalledWith({
      invoiceCustomSections: [{ id: 'cs_1', name: 'Bank details' }],
      skipInvoiceCustomSections: false,
    })
  })
})
