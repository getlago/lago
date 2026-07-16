import { toInvoiceCustomSectionReference } from '../utils'

describe('WHEN toInvoiceCustomSectionReference is called', () => {
  it('THEN returns undefined when input is undefined', () => {
    expect(toInvoiceCustomSectionReference(undefined)).toBeUndefined()
  })

  it('THEN returns undefined when input is null', () => {
    expect(toInvoiceCustomSectionReference(null)).toBeUndefined()
  })

  it('THEN converts invoiceCustomSections to invoiceCustomSectionIds', () => {
    const input = {
      invoiceCustomSections: [
        { id: 'section-1', name: 'Section 1' },
        { id: 'section-2', name: 'Section 2' },
      ],
      skipInvoiceCustomSections: false,
    }

    const result = toInvoiceCustomSectionReference(input)

    expect(result).toEqual({
      invoiceCustomSectionIds: ['section-1', 'section-2'],
      skipInvoiceCustomSections: false,
    })
  })

  it('THEN returns empty array when invoiceCustomSections is empty', () => {
    const input = {
      invoiceCustomSections: [],
      skipInvoiceCustomSections: false,
    }

    const result = toInvoiceCustomSectionReference(input)

    expect(result).toEqual({
      invoiceCustomSectionIds: [],
      skipInvoiceCustomSections: false,
    })
  })

  it('THEN returns empty array when invoiceCustomSections is undefined', () => {
    const input = {
      invoiceCustomSections: undefined as never,
      skipInvoiceCustomSections: true,
    }

    const result = toInvoiceCustomSectionReference(input)

    expect(result).toEqual({
      invoiceCustomSectionIds: [],
      skipInvoiceCustomSections: true,
    })
  })

  it('THEN preserves skipInvoiceCustomSections value', () => {
    const inputWithSkip = {
      invoiceCustomSections: [{ id: 'section-1', name: 'Section 1' }],
      skipInvoiceCustomSections: true,
    }

    const inputWithoutSkip = {
      invoiceCustomSections: [{ id: 'section-1', name: 'Section 1' }],
      skipInvoiceCustomSections: false,
    }

    expect(toInvoiceCustomSectionReference(inputWithSkip)?.skipInvoiceCustomSections).toBe(true)
    expect(toInvoiceCustomSectionReference(inputWithoutSkip)?.skipInvoiceCustomSections).toBe(false)
  })
})
