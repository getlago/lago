import { ComboBox } from '~/components/form'
import { InvoiceCustomSection, useInvoiceCustomSections } from '~/hooks/useInvoiceCustomSections'
import { render } from '~/test-utils'

import { createInvoiceCustomSection } from './factories/invoiceCustomSectionFactory'

import { InvoiceCustomerFooterSelection } from '../InvoiceCustomerFooterSelection'

jest.mock('~/components/form', () => ({
  ...jest.requireActual('~/components/form'),
  ComboBox: jest.fn(() => null),
}))

jest.mock('~/hooks/useInvoiceCustomSections', () => ({
  useInvoiceCustomSections: jest.fn(),
}))

const mockComboBox = jest.mocked(ComboBox)

const mockUseInvoiceCustomSections = jest.mocked(useInvoiceCustomSections)

describe('InvoiceCustomerFooterSelection', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('WHEN rendering with available sections', () => {
    it('THEN renders ComboBox with correct props', () => {
      mockUseInvoiceCustomSections.mockReturnValue({
        data: [
          createInvoiceCustomSection({ id: 'section-1', name: 'Section 1', code: 'SECTION_1' }),
        ],
        loading: false,
        error: false,
      })

      render(
        <InvoiceCustomerFooterSelection
          label="Select Invoice Section"
          name="customSectionSelect"
        />,
      )

      expect(mockComboBox).toHaveBeenCalledWith(
        expect.objectContaining({
          label: 'Select Invoice Section',
          name: 'customSectionSelect',
        }),
        {},
      )
    })
  })

  describe('WHEN handling loading and disabled state', () => {
    it('THEN disables ComboBox when loading is true', () => {
      mockUseInvoiceCustomSections.mockReturnValue({
        data: [],
        loading: true,
        error: false,
      })

      render(<InvoiceCustomerFooterSelection label="Select Section" />)

      expect(mockComboBox).toHaveBeenCalledWith(
        expect.objectContaining({
          disabled: true,
          loading: true,
        }),
        {},
      )
    })

    it('THEN disables ComboBox when externalDisabled prop is true', () => {
      mockUseInvoiceCustomSections.mockReturnValue({
        data: [
          createInvoiceCustomSection({ id: 'section-1', name: 'Section 1', code: 'SECTION_1' }),
        ],
        loading: false,
        error: false,
      })

      render(<InvoiceCustomerFooterSelection label="Select Section" disabled={true} />)

      expect(mockComboBox).toHaveBeenCalledWith(
        expect.objectContaining({
          disabled: true,
        }),
        {},
      )
    })
  })

  describe('WHEN selecting a section', () => {
    it('THEN renders ComboBox with options from useInvoiceCustomSections hook', () => {
      const sections = [
        createInvoiceCustomSection({ id: 'section-1', name: 'Section 1' }),
        createInvoiceCustomSection({ id: 'section-2', name: 'Section 2' }),
      ]

      mockUseInvoiceCustomSections.mockReturnValue({
        data: sections,
        loading: false,
        error: false,
      })

      render(<InvoiceCustomerFooterSelection />)

      expect(mockComboBox).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.arrayContaining([
            expect.objectContaining({
              value: 'section-1',
              label: 'Section 1',
            }),
            expect.objectContaining({
              value: 'section-2',
              label: 'Section 2',
            }),
          ]),
        }),
        {},
      )
    })
  })

  describe('WHEN handling selected sections', () => {
    it('THEN passes disabled options to ComboBox for already selected sections', () => {
      const alreadySelectedSections = [
        { id: 'section-1', name: 'Section 1' },
        { id: 'section-2', name: 'Section 2' },
      ]

      const orgSections: InvoiceCustomSection[] = [
        createInvoiceCustomSection({ id: 'section-1', name: 'Section 1' }),
        createInvoiceCustomSection({ id: 'section-2', name: 'Section 2' }),
        createInvoiceCustomSection({ id: 'section-3', name: 'Section 3' }),
      ]

      mockUseInvoiceCustomSections.mockReturnValue({
        data: orgSections,
        loading: false,
        error: false,
      })

      render(
        <InvoiceCustomerFooterSelection
          label="Select Section"
          invoiceCustomSelected={alreadySelectedSections}
        />,
      )

      expect(mockComboBox).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.arrayContaining([
            expect.objectContaining({
              value: 'section-1',
              disabled: true,
            }),
            expect.objectContaining({
              value: 'section-2',
              disabled: true,
            }),
            expect.objectContaining({
              value: 'section-3',
              disabled: false,
            }),
          ]),
        }),
        {},
      )
    })
  })
})
