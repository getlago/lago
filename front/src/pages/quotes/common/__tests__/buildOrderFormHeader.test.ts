import { buildOrderFormHeader } from '../buildOrderFormHeader'

const translate = ((key: string, data?: Record<string, unknown>) =>
  data ? `${key}:${JSON.stringify(data)}` : key) as never

describe('buildOrderFormHeader', () => {
  it('includes only the document-number row when expiresAt is absent', () => {
    const header = buildOrderFormHeader(
      { number: 'OF-1', expiresAt: null },
      translate,
      (iso) => iso,
    )

    expect(header.documentNumber).toBe('OF-1')
    expect(header.rows).toHaveLength(1)
    expect(header.rows[0]).toContain('text_1781778938224iupllzr5sgb')
  })

  it('appends a "valid until" row built from the formatted date when expiresAt is set', () => {
    const formatDate = jest.fn(() => 'Dec 31, 2026')

    const header = buildOrderFormHeader(
      { number: 'OF-1', expiresAt: '2026-12-31T00:00:00Z' },
      translate,
      formatDate,
    )

    expect(formatDate).toHaveBeenCalledWith('2026-12-31T00:00:00Z')
    expect(header.rows).toHaveLength(2)
    expect(header.rows[1]).toContain('Dec 31, 2026')
  })

  it('falls back to an empty document number when number is nullish', () => {
    const header = buildOrderFormHeader({ number: null, expiresAt: null }, translate, (iso) => iso)

    expect(header.documentNumber).toBe('')
  })
})
