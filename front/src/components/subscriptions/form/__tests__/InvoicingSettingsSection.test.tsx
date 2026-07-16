import { render } from '~/test-utils'

import { InvoicingSettingsSection } from '../InvoicingSettingsSection'

const mockSelector: jest.Mock<null, [Record<string, unknown>]> = jest.fn()
const mockDrawer: jest.Mock<null, [Record<string, unknown>]> = jest.fn()

jest.mock('~/components/designSystem/Selector', () => ({
  Selector: (props: Record<string, unknown>) => {
    mockSelector(props)

    return null
  },
}))

jest.mock('../InvoicingSettingsDrawer', () => ({
  InvoicingSettingsDrawer: function MockInvoicingSettingsDrawer(props: Record<string, unknown>) {
    mockDrawer(props)

    return null
  },
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

jest.mock('@tanstack/react-form', () => ({
  revalidateLogic: jest.fn(() => ({})),
  useStore: (store: { state: unknown }, selector: (state: unknown) => unknown) =>
    selector(store.state),
}))

jest.mock('~/hooks/forms/useAppform', () => ({
  useAppForm: jest.fn(),
  withForm: jest.fn(
    ({
      render: RenderComponent,
      props: defaultProps,
    }: {
      render: React.FC<Record<string, unknown>>
      defaultValues: Record<string, unknown>
      props: Record<string, unknown>
    }) => {
      const WithFormWrapper = (receivedProps: Record<string, unknown>) => (
        <RenderComponent {...defaultProps} {...receivedProps} />
      )

      WithFormWrapper.displayName = 'WithFormWrapper'

      return WithFormWrapper
    },
  ),
}))

const renderSection = (
  values: { consolidateInvoice?: boolean; invoiceCustomSection?: unknown },
  customerId?: string,
) => {
  const state = { values }
  const form = { setFieldValue: jest.fn(), state, store: { state } }

  render(
    // @ts-expect-error - mock form shape
    <InvoicingSettingsSection form={form} customerId={customerId} />,
  )

  return { form }
}

const lastSubtitle = () =>
  (mockSelector.mock.calls.at(-1)?.[0] as { subtitle?: string } | undefined)?.subtitle

describe('InvoicingSettingsSection', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('summarises consolidation + customer-default custom sections', () => {
    renderSection(
      {
        consolidateInvoice: true,
        invoiceCustomSection: { invoiceCustomSections: [], skipInvoiceCustomSections: false },
      },
      'cust-1',
    )

    expect(lastSubtitle()).toBe('text_1778745351091h7z5baw0ta6 • text_1782738644347svkr94bf4aw')
  })

  it('summarises isolate + specific custom sections', () => {
    renderSection(
      {
        consolidateInvoice: false,
        invoiceCustomSection: {
          invoiceCustomSections: [{ id: 'cs_1', name: 'Bank details' }],
          skipInvoiceCustomSections: false,
        },
      },
      'cust-1',
    )

    expect(lastSubtitle()).toBe('text_1778745351091fxaqr5dwok8 • text_1782738644347qh5s13lol1p')
  })

  it('summarises the skip behaviour for custom sections', () => {
    renderSection(
      {
        consolidateInvoice: true,
        invoiceCustomSection: { invoiceCustomSections: [], skipInvoiceCustomSections: true },
      },
      'cust-1',
    )

    expect(lastSubtitle()).toBe('text_1778745351091h7z5baw0ta6 • text_1782738644347z3azl4u1f15')
  })

  it('omits the custom-section part when the customer has no id', () => {
    renderSection({ consolidateInvoice: true })

    expect(lastSubtitle()).toBe('text_1778745351091h7z5baw0ta6')
    expect(mockDrawer).toHaveBeenCalledWith(expect.objectContaining({ showCustomSection: false }))
  })

  it('wires the drawer onSave back to the form fields', () => {
    const { form } = renderSection({ consolidateInvoice: true }, 'cust-1')

    const { onSave } = mockDrawer.mock.calls.at(-1)?.[0] as {
      onSave: (v: { consolidateInvoice: boolean; invoiceCustomSection: unknown }) => void
    }

    const nextIcs = { invoiceCustomSections: [], skipInvoiceCustomSections: true }

    onSave({ consolidateInvoice: false, invoiceCustomSection: nextIcs })

    expect(form.setFieldValue).toHaveBeenCalledWith('consolidateInvoice', false)
    expect(form.setFieldValue).toHaveBeenCalledWith('invoiceCustomSection', nextIcs)
  })
})
