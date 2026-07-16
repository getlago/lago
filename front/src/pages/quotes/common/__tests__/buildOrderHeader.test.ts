import { buildOrderHeader } from '../buildOrderHeader'

const translate = (key: string, vars?: Record<string, unknown>) =>
  vars ? `${key}:${JSON.stringify(vars)}` : key

describe('buildOrderHeader', () => {
  it('returns the order number as documentNumber and a single Order # row', () => {
    const result = buildOrderHeader({ number: 'OR-2026-0001' }, translate)

    expect(result).toEqual({
      documentNumber: 'OR-2026-0001',
      rows: ['text_1782723591984l12xpznkwqd:{"orderNumber":"OR-2026-0001"}'],
    })
  })

  it('falls back to an empty string when number is missing', () => {
    const result = buildOrderHeader({ number: null }, translate)

    expect(result.documentNumber).toBe('')
    expect(result.rows).toHaveLength(1)
  })
})
