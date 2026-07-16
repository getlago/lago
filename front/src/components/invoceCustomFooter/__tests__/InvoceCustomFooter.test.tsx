import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { ViewTypeEnum } from '~/components/paymentMethodsInvoiceSettings/types'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCustomerInvoiceCustomSections } from '~/hooks/useCustomerInvoiceCustomSections'
import { useInvoiceCustomSections } from '~/hooks/useInvoiceCustomSections'
import { render } from '~/test-utils'

import { EDIT_BUTTON, InvoceCustomFooter } from '../InvoceCustomFooter'
import { FALLBACK_BILLING_ENTITY_LABEL, SECTION_CHIP } from '../InvoiceCustomSectionDisplay'
import { InvoiceCustomSectionBasic } from '../types'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: jest.fn(),
}))

jest.mock('~/hooks/useCustomerInvoiceCustomSections', () => ({
  useCustomerInvoiceCustomSections: jest.fn(),
}))

jest.mock('~/hooks/useInvoiceCustomSections', () => ({
  useInvoiceCustomSections: jest.fn(),
}))

let capturedOnSave:
  | ((selection: { behavior: string; selectedSections: InvoiceCustomSectionBasic[] }) => void)
  | undefined

jest.mock('~/components/invoceCustomFooter/EditInvoiceCustomSectionDialog', () => ({
  EditInvoiceCustomSectionDialog: jest.fn(
    ({
      onSave,
    }: {
      onSave?: (selection: {
        behavior: string
        selectedSections: InvoiceCustomSectionBasic[]
      }) => void
    }) => {
      // Capture onSave for testing
      if (onSave) {
        capturedOnSave = onSave
      }
      return null
    },
  ),
  InvoiceCustomSectionBehavior: {
    FALLBACK: 'fallback',
    APPLY: 'apply',
    NONE: 'none',
  },
}))

const mockUseInternationalization = jest.mocked(useInternationalization)
const mockUseCustomerInvoiceCustomSections = jest.mocked(useCustomerInvoiceCustomSections)
const mockUseInvoiceCustomSections = jest.mocked(useInvoiceCustomSections)

const defaultCustomerData = {
  customerId: 'customer-1',
  externalId: 'ext-customer-1',
  configurableInvoiceCustomSections: [
    { id: 'section-1', name: 'Section 1' },
    { id: 'section-2', name: 'Section 2' },
  ],
  hasOverwrittenInvoiceCustomSectionsSelection: false,
  skipInvoiceCustomSections: false,
}

const defaultOrgSections = [
  { id: 'section-1', name: 'Section 1', code: 'section-1' },
  { id: 'section-2', name: 'Section 2', code: 'section-2' },
  { id: 'section-3', name: 'Section 3', code: 'section-3' },
]

describe('InvoceCustomFooter', () => {
  beforeEach(() => {
    jest.clearAllMocks()

    mockUseInternationalization.mockReturnValue({
      translate: (key: string) => key,
      locale: 'en',
    } as ReturnType<typeof useInternationalization>)

    mockUseCustomerInvoiceCustomSections.mockReturnValue({
      data: defaultCustomerData,
      loading: false,
      error: false,
      customer: null,
    } as ReturnType<typeof useCustomerInvoiceCustomSections>)

    mockUseInvoiceCustomSections.mockReturnValue({
      data: defaultOrgSections,
      loading: false,
      error: false,
    })
  })

  describe('WHEN APPLY behavior is selected', () => {
    it('THEN displays chips for explicitly selected sections', async () => {
      render(
        <InvoceCustomFooter
          customerId="customer-1"
          viewType={ViewTypeEnum.Subscription}
          invoiceCustomSection={{
            invoiceCustomSections: [
              { id: 'section-1', name: 'Section 1' },
              { id: 'section-3', name: 'Section 3' },
            ],
            skipInvoiceCustomSections: false,
          }}
        />,
      )

      await waitFor(() => {
        expect(screen.getByText('Section 1')).toBeInTheDocument()
        expect(screen.getByText('Section 3')).toBeInTheDocument()
        expect(screen.getByTestId(SECTION_CHIP('section-1'))).toBeInTheDocument()
        expect(screen.getByTestId(SECTION_CHIP('section-3'))).toBeInTheDocument()
      })

      // Should not display section-2 as it's not in the selected list
      expect(screen.queryByText('Section 2')).not.toBeInTheDocument()
    })

    it('THEN passes correct selected sections to dialog when opening edit dialog', async () => {
      render(
        <InvoceCustomFooter
          customerId="customer-1"
          viewType={ViewTypeEnum.Subscription}
          invoiceCustomSection={{
            invoiceCustomSections: [
              { id: 'section-1', name: 'Section 1' },
              { id: 'section-2', name: 'Section 2' },
            ],
            skipInvoiceCustomSections: false,
          }}
        />,
      )

      const editButton = screen.getByTestId(EDIT_BUTTON)

      await userEvent.click(editButton)

      // Verify dialog receives the selected sections (mapped from IDs to { id, name })
      const { EditInvoiceCustomSectionDialog } = jest.requireMock(
        '~/components/invoceCustomFooter/EditInvoiceCustomSectionDialog',
      )

      const dialogCall = EditInvoiceCustomSectionDialog.mock.calls[0]?.[0]

      expect(dialogCall?.selectedSections).toEqual([
        { id: 'section-1', name: 'Section 1' },
        { id: 'section-2', name: 'Section 2' },
      ])
    })
  })

  describe('WHEN NONE behavior is selected', () => {
    it('THEN does not display sections when skipInvoiceCustomSections is true', async () => {
      render(
        <InvoceCustomFooter
          customerId="customer-1"
          viewType={ViewTypeEnum.Subscription}
          invoiceCustomSection={{
            invoiceCustomSections: [{ id: 'section-1', name: 'Section 1' }],
            skipInvoiceCustomSections: true,
          }}
        />,
      )

      await waitFor(() => {
        // Should not display any chips
        expect(screen.queryByText('Section 1')).not.toBeInTheDocument()
        expect(screen.queryByTestId(SECTION_CHIP('section-1'))).not.toBeInTheDocument()
      })
    })
  })

  describe('WHEN FALLBACK behavior is selected and customer has overwritten selection', () => {
    it('THEN displays customer sections when hasOverwrittenInvoiceCustomSectionsSelection is true', async () => {
      mockUseCustomerInvoiceCustomSections.mockReturnValue({
        data: {
          ...defaultCustomerData,
          hasOverwrittenInvoiceCustomSectionsSelection: true,
          skipInvoiceCustomSections: false,
          configurableInvoiceCustomSections: [
            { id: 'section-1', name: 'Customer Section 1' },
            { id: 'section-2', name: 'Customer Section 2' },
          ],
        },
        loading: false,
        error: false,
        customer: null,
      } as ReturnType<typeof useCustomerInvoiceCustomSections>)

      render(
        <InvoceCustomFooter
          customerId="customer-1"
          viewType={ViewTypeEnum.Subscription}
          invoiceCustomSection={{
            invoiceCustomSections: [],
            skipInvoiceCustomSections: false,
          }}
        />,
      )

      await waitFor(() => {
        expect(screen.getByText('Customer Section 1')).toBeInTheDocument()
        expect(screen.getByText('Customer Section 2')).toBeInTheDocument()
        expect(screen.getByTestId(SECTION_CHIP('section-1'))).toBeInTheDocument()
        expect(screen.getByTestId(SECTION_CHIP('section-2'))).toBeInTheDocument()
      })
    })

    it('THEN displays customer skip message when customer has skipInvoiceCustomSections=true and hasOverwrittenInvoiceCustomSectionsSelection=false', async () => {
      mockUseCustomerInvoiceCustomSections.mockReturnValue({
        data: {
          ...defaultCustomerData,
          hasOverwrittenInvoiceCustomSectionsSelection: false,
          skipInvoiceCustomSections: true,
        },
        loading: false,
        error: false,
        customer: null,
      } as ReturnType<typeof useCustomerInvoiceCustomSections>)

      render(
        <InvoceCustomFooter
          customerId="customer-1"
          viewType={ViewTypeEnum.Subscription}
          invoiceCustomSection={{
            invoiceCustomSections: [],
            skipInvoiceCustomSections: false,
          }}
        />,
      )

      await waitFor(() => {
        // Should not display any chips
        expect(screen.queryByText('Section 1')).not.toBeInTheDocument()
        expect(screen.queryByTestId(SECTION_CHIP('section-1'))).not.toBeInTheDocument()
      })
    })
  })

  describe('WHEN FALLBACK behavior is selected and customer has not overwritten selection', () => {
    it('THEN displays billing entity sections when customer has not overwritten selection', async () => {
      mockUseCustomerInvoiceCustomSections.mockReturnValue({
        data: {
          ...defaultCustomerData,
          hasOverwrittenInvoiceCustomSectionsSelection: false,
          skipInvoiceCustomSections: false,
          configurableInvoiceCustomSections: [
            { id: 'section-1', name: 'Billing Entity Section 1' },
            { id: 'section-2', name: 'Billing Entity Section 2' },
          ],
        },
        loading: false,
        error: false,
        customer: null,
      } as ReturnType<typeof useCustomerInvoiceCustomSections>)

      render(
        <InvoceCustomFooter
          customerId="customer-1"
          viewType={ViewTypeEnum.Subscription}
          invoiceCustomSection={{
            invoiceCustomSections: [],
            skipInvoiceCustomSections: false,
          }}
        />,
      )

      await waitFor(() => {
        expect(screen.getByTestId(FALLBACK_BILLING_ENTITY_LABEL)).toBeInTheDocument()
        expect(screen.getByText('Billing Entity Section 1')).toBeInTheDocument()
        expect(screen.getByText('Billing Entity Section 2')).toBeInTheDocument()
        expect(screen.getByTestId(SECTION_CHIP('section-1'))).toBeInTheDocument()
        expect(screen.getByTestId(SECTION_CHIP('section-2'))).toBeInTheDocument()
      })
    })

    it('THEN displays empty state when no sections are available from billing entity', async () => {
      mockUseCustomerInvoiceCustomSections.mockReturnValue({
        data: {
          ...defaultCustomerData,
          hasOverwrittenInvoiceCustomSectionsSelection: false,
          skipInvoiceCustomSections: false,
          configurableInvoiceCustomSections: [],
        },
        loading: false,
        error: false,
        customer: null,
      } as ReturnType<typeof useCustomerInvoiceCustomSections>)

      render(
        <InvoceCustomFooter
          customerId="customer-1"
          viewType={ViewTypeEnum.Subscription}
          invoiceCustomSection={{
            invoiceCustomSections: [],
            skipInvoiceCustomSections: false,
          }}
        />,
      )

      await waitFor(() => {
        // Should not display any sections or labels
        expect(screen.queryByTestId(FALLBACK_BILLING_ENTITY_LABEL)).not.toBeInTheDocument()
        expect(screen.queryByText('Section 1')).not.toBeInTheDocument()
      })

      // Edit button should still be visible
      expect(screen.getByTestId(EDIT_BUTTON)).toBeInTheDocument()
    })
  })

  describe('WHEN dialog interaction occurs', () => {
    beforeEach(() => {
      capturedOnSave = undefined
    })

    it('THEN opens dialog when edit button is clicked', async () => {
      render(<InvoceCustomFooter customerId="customer-1" viewType={ViewTypeEnum.Subscription} />)

      const editButton = screen.getByTestId(EDIT_BUTTON)

      await userEvent.click(editButton)

      // Verify dialog is called with open=true
      const { EditInvoiceCustomSectionDialog } = jest.requireMock(
        '~/components/invoceCustomFooter/EditInvoiceCustomSectionDialog',
      )

      expect(EditInvoiceCustomSectionDialog).toHaveBeenCalledWith(
        expect.objectContaining({
          open: true,
        }),
        expect.anything(),
      )
    })

    it('THEN passes correct props to dialog based on current behavior', async () => {
      render(
        <InvoceCustomFooter
          customerId="customer-1"
          viewType={ViewTypeEnum.Subscription}
          invoiceCustomSection={{
            invoiceCustomSections: [{ id: 'section-1', name: 'Section 1' }],
            skipInvoiceCustomSections: true,
          }}
        />,
      )

      const { EditInvoiceCustomSectionDialog } = jest.requireMock(
        '~/components/invoceCustomFooter/EditInvoiceCustomSectionDialog',
      )

      const dialogCall = EditInvoiceCustomSectionDialog.mock.calls[0]?.[0]

      expect(dialogCall?.skipInvoiceCustomSections).toBe(true)
      // The component passes selectedSections to the dialog regardless of skipInvoiceCustomSections
      // The dialog will determine the initial behavior based on skipInvoiceCustomSections
      expect(dialogCall?.selectedSections).toEqual([{ id: 'section-1', name: 'Section 1' }])
    })

    it('THEN displays default title and description', async () => {
      render(<InvoceCustomFooter customerId="customer-1" viewType={ViewTypeEnum.Subscription} />)

      // The component displays hardcoded translation keys
      expect(screen.getByText('text_17628623882713knw0jtohiw')).toBeInTheDocument()
    })
  })

  describe('WHEN handleDialogSave is called', () => {
    beforeEach(() => {
      capturedOnSave = undefined
    })

    it('THEN calls setInvoiceCustomSection with FALLBACK behavior values', async () => {
      const setInvoiceCustomSection = jest.fn()

      render(
        <InvoceCustomFooter
          customerId="customer-1"
          viewType={ViewTypeEnum.Subscription}
          setInvoiceCustomSection={setInvoiceCustomSection}
        />,
      )

      const editButton = screen.getByTestId(EDIT_BUTTON)

      await userEvent.click(editButton)

      // Wait for dialog to be initialized and onSave to be captured
      await waitFor(() => {
        expect(capturedOnSave).toBeDefined()
      })

      // Call onSave with FALLBACK behavior
      const { InvoiceCustomSectionBehavior } = jest.requireMock(
        '~/components/invoceCustomFooter/EditInvoiceCustomSectionDialog',
      )

      capturedOnSave?.({
        behavior: InvoiceCustomSectionBehavior.FALLBACK,
        selectedSections: [],
      })

      expect(setInvoiceCustomSection).toHaveBeenCalledWith({
        invoiceCustomSections: [],
        skipInvoiceCustomSections: false,
      })
    })

    it('THEN calls setInvoiceCustomSection with APPLY behavior values', async () => {
      const setInvoiceCustomSection = jest.fn()
      const selectedSections: InvoiceCustomSectionBasic[] = [
        { id: 'section-1', name: 'Section 1' },
        { id: 'section-2', name: 'Section 2' },
      ]

      render(
        <InvoceCustomFooter
          customerId="customer-1"
          viewType={ViewTypeEnum.Subscription}
          setInvoiceCustomSection={setInvoiceCustomSection}
        />,
      )

      const editButton = screen.getByTestId(EDIT_BUTTON)

      await userEvent.click(editButton)

      // Wait for dialog to be initialized and onSave to be captured
      await waitFor(() => {
        expect(capturedOnSave).toBeDefined()
      })

      // Call onSave with APPLY behavior
      const { InvoiceCustomSectionBehavior } = jest.requireMock(
        '~/components/invoceCustomFooter/EditInvoiceCustomSectionDialog',
      )

      capturedOnSave?.({
        behavior: InvoiceCustomSectionBehavior.APPLY,
        selectedSections,
      })

      expect(setInvoiceCustomSection).toHaveBeenCalledWith({
        invoiceCustomSections: selectedSections,
        skipInvoiceCustomSections: false,
      })
    })

    it('THEN calls setInvoiceCustomSection with NONE behavior values', async () => {
      const setInvoiceCustomSection = jest.fn()

      render(
        <InvoceCustomFooter
          customerId="customer-1"
          viewType={ViewTypeEnum.Subscription}
          setInvoiceCustomSection={setInvoiceCustomSection}
        />,
      )

      const editButton = screen.getByTestId(EDIT_BUTTON)

      await userEvent.click(editButton)

      // Wait for dialog to be initialized and onSave to be captured
      await waitFor(() => {
        expect(capturedOnSave).toBeDefined()
      })

      // Call onSave with NONE behavior
      const { InvoiceCustomSectionBehavior } = jest.requireMock(
        '~/components/invoceCustomFooter/EditInvoiceCustomSectionDialog',
      )

      capturedOnSave?.({
        behavior: InvoiceCustomSectionBehavior.NONE,
        selectedSections: [],
      })

      expect(setInvoiceCustomSection).toHaveBeenCalledWith({
        invoiceCustomSections: [],
        skipInvoiceCustomSections: true,
      })
    })
  })
})
