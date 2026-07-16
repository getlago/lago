import { act, cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { ViewTypeEnum } from '~/components/paymentMethodsInvoiceSettings/types'
import { render } from '~/test-utils'

import { EditInvoiceCustomSectionDialog } from '../EditInvoiceCustomSectionDialog'
import { EDIT_ICS_DIALOG_SAVE_BUTTON_TEST_ID } from '../EditInvoiceCustomSectionDialogActions'
import {
  InvoiceCustomSectionBasic,
  InvoiceCustomSectionBehavior,
  InvoiceCustomSectionInput,
} from '../types'

// The selector content is unit-tested in InvoiceCustomSectionFields.test; here
// we only verify the dialog shell: seeding the draft, mapping it to a selection
// on save, and closing.
const mockFieldsProps: {
  current: {
    value?: InvoiceCustomSectionInput
    onChange: (v: InvoiceCustomSectionInput) => void
    onBehaviorChange?: (b: InvoiceCustomSectionBehavior) => void
  } | null
} = { current: null }

jest.mock('../InvoiceCustomSectionFields', () => ({
  InvoiceCustomSectionFields: (props: {
    value?: InvoiceCustomSectionInput
    onChange: (v: InvoiceCustomSectionInput) => void
    onBehaviorChange?: (b: InvoiceCustomSectionBehavior) => void
  }) => {
    mockFieldsProps.current = props

    return <div data-test="ics-fields" />
  },
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key, locale: 'en' }),
}))

function prepare({
  open = true,
  selectedSections = [],
  skipInvoiceCustomSections = false,
  onSave = jest.fn(),
  onClose = jest.fn(),
}: {
  open?: boolean
  selectedSections?: InvoiceCustomSectionBasic[]
  skipInvoiceCustomSections?: boolean
  onSave?: jest.Mock
  onClose?: jest.Mock
} = {}) {
  render(
    <EditInvoiceCustomSectionDialog
      open={open}
      onClose={onClose}
      customerId="cust_1"
      selectedSections={selectedSections}
      skipInvoiceCustomSections={skipInvoiceCustomSections}
      onSave={onSave}
      viewType={ViewTypeEnum.Subscription}
    />,
  )

  return { onSave, onClose }
}

describe('EditInvoiceCustomSectionDialog', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
    mockFieldsProps.current = null
  })

  it('seeds the shared fields with the current selection on open', async () => {
    const selectedSections = [{ id: 'section-1', name: 'Section 1' }]

    await act(() => prepare({ selectedSections, skipInvoiceCustomSections: false }))

    expect(screen.getByTestId('ics-fields')).toBeInTheDocument()
    expect(mockFieldsProps.current?.value).toEqual({
      invoiceCustomSections: selectedSections,
      skipInvoiceCustomSections: false,
    })
  })

  it('saves an APPLY selection (sections present) and closes', async () => {
    const user = userEvent.setup()
    const selectedSections = [
      { id: 'section-1', name: 'Section 1' },
      { id: 'section-2', name: 'Section 2' },
    ]

    const { onSave, onClose } = await act(() => prepare({ selectedSections }))

    await user.click(screen.getByTestId(EDIT_ICS_DIALOG_SAVE_BUTTON_TEST_ID))

    expect(onSave).toHaveBeenCalledWith({
      behavior: InvoiceCustomSectionBehavior.APPLY,
      selectedSections,
    })
    expect(onClose).toHaveBeenCalledTimes(1)
  })

  it('saves a NONE selection when the draft skips sections', async () => {
    const user = userEvent.setup()
    const { onSave } = await act(() => prepare())

    act(() => {
      mockFieldsProps.current?.onChange({
        invoiceCustomSections: [],
        skipInvoiceCustomSections: true,
      })
    })

    await user.click(screen.getByTestId(EDIT_ICS_DIALOG_SAVE_BUTTON_TEST_ID))

    expect(onSave).toHaveBeenCalledWith({
      behavior: InvoiceCustomSectionBehavior.NONE,
      selectedSections: [],
    })
  })

  it('disables save when "apply" is picked without any sections', async () => {
    await act(() => prepare())

    act(() => {
      mockFieldsProps.current?.onBehaviorChange?.(InvoiceCustomSectionBehavior.APPLY)
      mockFieldsProps.current?.onChange({
        invoiceCustomSections: [],
        skipInvoiceCustomSections: false,
      })
    })

    expect(screen.getByTestId(EDIT_ICS_DIALOG_SAVE_BUTTON_TEST_ID)).toBeDisabled()
  })

  it('saves a FALLBACK selection when the draft is empty', async () => {
    const user = userEvent.setup()
    const { onSave } = await act(() =>
      prepare({ selectedSections: [{ id: 'section-1', name: 'Section 1' }] }),
    )

    // User switches back to the fallback behavior, clearing the selection.
    act(() => {
      mockFieldsProps.current?.onBehaviorChange?.(InvoiceCustomSectionBehavior.FALLBACK)
      mockFieldsProps.current?.onChange({
        invoiceCustomSections: [],
        skipInvoiceCustomSections: false,
      })
    })

    await user.click(screen.getByTestId(EDIT_ICS_DIALOG_SAVE_BUTTON_TEST_ID))

    expect(onSave).toHaveBeenCalledWith({
      behavior: InvoiceCustomSectionBehavior.FALLBACK,
      selectedSections: [],
    })
  })
})
