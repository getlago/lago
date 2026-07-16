import { screen } from '@testing-library/react'
import { ReactElement } from 'react'

import { Customer } from '~/generated/graphql'
import { render } from '~/test-utils'

import { InvoiceCustomSectionSettings } from '../InvoiceCustomSectionSettings'
import { PaymentMethodsForm, ViewTypeEnum } from '../types'

const mockInvoceCustomFooter = jest.fn<ReactElement, [Record<string, unknown>]>(() => (
  <div data-test="invoice-custom-footer" />
))

jest.mock('~/components/invoceCustomFooter/InvoceCustomFooter', () => ({
  InvoceCustomFooter: (props: Record<string, unknown>) => mockInvoceCustomFooter(props),
}))

const buildForm = (
  values: Record<string, unknown>,
): PaymentMethodsForm<ViewTypeEnum.Subscription> =>
  ({
    values,
    setFieldValue: jest.fn(),
  }) as unknown as PaymentMethodsForm<ViewTypeEnum.Subscription>

describe('InvoiceCustomSectionSettings', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('returns null when customer is null', () => {
    const { container } = render(
      <InvoiceCustomSectionSettings
        customer={null}
        form={buildForm({})}
        viewType={ViewTypeEnum.Subscription}
      />,
    )

    expect(container.firstChild).toBeNull()
    expect(mockInvoceCustomFooter).not.toHaveBeenCalled()
  })

  it('returns null when customer has no id', () => {
    const customer = { id: null, externalId: 'ext_1' } as unknown as Customer

    const { container } = render(
      <InvoiceCustomSectionSettings
        customer={customer}
        form={buildForm({})}
        viewType={ViewTypeEnum.Subscription}
      />,
    )

    expect(container.firstChild).toBeNull()
    expect(mockInvoceCustomFooter).not.toHaveBeenCalled()
  })

  it('renders InvoceCustomFooter and forwards customerId + selected value', () => {
    const customer = { id: 'cust_1', externalId: 'ext_1' } as Customer
    const invoiceCustomSection = {
      invoiceCustomSections: ['cs_1'],
      skipInvoiceCustomSections: false,
    }

    render(
      <InvoiceCustomSectionSettings
        customer={customer}
        form={buildForm({ invoiceCustomSection })}
        viewType={ViewTypeEnum.Subscription}
      />,
    )

    expect(screen.getByTestId('invoice-custom-footer')).toBeInTheDocument()
    expect(mockInvoceCustomFooter).toHaveBeenCalledWith(
      expect.objectContaining({
        customerId: 'cust_1',
        viewType: ViewTypeEnum.Subscription,
        invoiceCustomSection,
      }),
    )
  })

  it('passes undefined when no invoiceCustomSection value is set', () => {
    const customer = { id: 'cust_1', externalId: 'ext_1' } as Customer

    render(
      <InvoiceCustomSectionSettings
        customer={customer}
        form={buildForm({})}
        viewType={ViewTypeEnum.Subscription}
      />,
    )

    expect(mockInvoceCustomFooter).toHaveBeenCalledWith(
      expect.objectContaining({ invoiceCustomSection: undefined }),
    )
  })

  it('writes the invoiceCustomSection field via setFieldValue', () => {
    const customer = { id: 'cust_1', externalId: 'ext_1' } as Customer
    const form = buildForm({})

    render(
      <InvoiceCustomSectionSettings
        customer={customer}
        form={form}
        viewType={ViewTypeEnum.Subscription}
      />,
    )

    const { setInvoiceCustomSection } = mockInvoceCustomFooter.mock.calls[0][0] as {
      setInvoiceCustomSection: (item: unknown) => void
    }
    const next = { invoiceCustomSections: ['cs_2'], skipInvoiceCustomSections: false }

    setInvoiceCustomSection(next)

    expect(form.setFieldValue).toHaveBeenCalledWith('invoiceCustomSection', next)
  })

  it('respects formFieldBasePath for nested reads and writes', () => {
    const customer = { id: 'cust_1', externalId: 'ext_1' } as Customer
    const nested = { invoiceCustomSections: ['cs_nested'], skipInvoiceCustomSections: false }
    const form = buildForm({ recurringTransactionRules: [{ invoiceCustomSection: nested }] })

    render(
      <InvoiceCustomSectionSettings
        customer={customer}
        form={form}
        viewType={ViewTypeEnum.WalletRecurringTopUp}
        formFieldBasePath="recurringTransactionRules.0"
      />,
    )

    expect(mockInvoceCustomFooter).toHaveBeenCalledWith(
      expect.objectContaining({ invoiceCustomSection: nested }),
    )

    const { setInvoiceCustomSection } = mockInvoceCustomFooter.mock.calls[0][0] as {
      setInvoiceCustomSection: (item: unknown) => void
    }
    const next = { invoiceCustomSections: ['cs_new'], skipInvoiceCustomSections: true }

    setInvoiceCustomSection(next)

    expect(form.setFieldValue).toHaveBeenCalledWith(
      'recurringTransactionRules.0.invoiceCustomSection',
      next,
    )
  })
})
