import { act, createRef, ReactNode } from 'react'

import { InvoiceCustomSectionBehavior } from '~/components/invoceCustomFooter/types'
import { render } from '~/test-utils'

import { ViewTypeEnum } from '../../../paymentMethodsInvoiceSettings/types'
import { InvoicingSettingsDrawer, InvoicingSettingsDrawerRef } from '../InvoicingSettingsDrawer'

const mockOpen = jest.fn()
const mockClose = jest.fn()

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key, locale: 'en' }),
}))

jest.mock('~/components/drawers/useDrawer', () => ({
  useFormDrawer: () => ({ open: mockOpen, close: mockClose }),
}))

jest.mock('~/components/drawers/useFocusTrap', () => ({
  focusFirstInput: jest.fn(),
}))

jest.mock('~/components/subscriptions/SubscriptionInvoiceConsolidationSection', () => ({
  SubscriptionInvoiceConsolidationSection: () => <div data-test="consolidation" />,
}))

const mockIcsProps: {
  current: {
    error?: string
    onBehaviorChange?: (behavior: InvoiceCustomSectionBehavior) => void
  } | null
} = { current: null }

jest.mock('~/components/invoceCustomFooter/InvoiceCustomSectionFields', () => ({
  InvoiceCustomSectionFields: (props: {
    error?: string
    onBehaviorChange?: (behavior: InvoiceCustomSectionBehavior) => void
  }) => {
    mockIcsProps.current = props

    return <div data-test="ics-fields" />
  },
}))

describe('InvoicingSettingsDrawer', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockIcsProps.current = null
  })

  const renderDrawer = (onSave = jest.fn()) => {
    const ref = createRef<InvoicingSettingsDrawerRef>()

    render(
      <InvoicingSettingsDrawer
        ref={ref}
        viewType={ViewTypeEnum.Subscription}
        customerId="cust_1"
        showCustomSection
        onSave={onSave}
      />,
    )

    return { ref, onSave }
  }

  it('renders nothing until opened', () => {
    const { container } = render(
      <InvoicingSettingsDrawer
        viewType={ViewTypeEnum.Subscription}
        customerId="cust_1"
        showCustomSection
        onSave={jest.fn()}
      />,
    )

    expect(container.firstChild).toBeNull()
    expect(mockOpen).not.toHaveBeenCalled()
  })

  it('opens the drawer with the Invoicing settings title', () => {
    const { ref } = renderDrawer()

    act(() => {
      ref.current?.openDrawer({
        consolidateInvoice: true,
        invoiceCustomSection: { invoiceCustomSections: [], skipInvoiceCustomSections: false },
      })
    })

    expect(mockOpen).toHaveBeenCalledTimes(1)
    expect(mockOpen).toHaveBeenCalledWith(
      expect.objectContaining({ title: 'text_17423672025282dl7iozy1ru' }),
    )
  })

  it('commits the seeded draft through onSave on submit, then closes', async () => {
    const { ref, onSave } = renderDrawer()

    const seeded = {
      consolidateInvoice: false,
      invoiceCustomSection: {
        invoiceCustomSections: [{ id: 'cs_1', name: 'Bank details' }],
        skipInvoiceCustomSections: false,
      },
    }

    act(() => {
      ref.current?.openDrawer(seeded)
    })

    const { form } = mockOpen.mock.calls[0][0] as { form: { submit: () => Promise<void> } }

    await act(async () => {
      await form.submit()
    })

    expect(onSave).toHaveBeenCalledWith(seeded)
    expect(mockClose).toHaveBeenCalled()
  })

  it('blocks submit and surfaces the error when "apply" is picked with no section', async () => {
    const { ref, onSave } = renderDrawer()

    act(() => {
      ref.current?.openDrawer({
        consolidateInvoice: true,
        invoiceCustomSection: { invoiceCustomSections: [], skipInvoiceCustomSections: false },
      })
    })

    const opened = mockOpen.mock.calls[0][0] as {
      form: { submit: () => Promise<void> }
      children: ReactNode
    }

    // Mount the drawer content so the field error can surface on the inline
    // fields (drawer.open is mocked, so children isn't rendered otherwise).
    render(<>{opened.children}</>)

    // User picks "apply" without selecting any section (value stays empty).
    act(() => {
      mockIcsProps.current?.onBehaviorChange?.(InvoiceCustomSectionBehavior.APPLY)
    })

    await act(async () => {
      await opened.form.submit()
    })

    expect(onSave).not.toHaveBeenCalled()
    expect(mockClose).not.toHaveBeenCalled()
    expect(mockIcsProps.current?.error).toBe('text_624ea7c29103fd010732ab7d')
  })
})
