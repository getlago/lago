import { OPTION_VALUE_SEPARATOR } from '../const'
import { stringifyOptionValue } from '../stringifyOptionValue'

describe('stringifyOptionValue', () => {
  it('should stringify option value with all fields correctly', () => {
    const result = stringifyOptionValue({
      externalId: '123',
      externalAccountCode: 'ACC001',
      externalName: 'Sales Revenue',
    })

    expect(result).toBe(`123${OPTION_VALUE_SEPARATOR}ACC001${OPTION_VALUE_SEPARATOR}Sales Revenue`)
  })

  it('should handle empty strings correctly', () => {
    const result = stringifyOptionValue({
      externalId: '',
      externalAccountCode: '',
      externalName: '',
    })

    expect(result).toBe(`${OPTION_VALUE_SEPARATOR}${OPTION_VALUE_SEPARATOR}`)
  })

  it('should handle mixed empty and filled values', () => {
    const result = stringifyOptionValue({
      externalId: '456',
      externalAccountCode: '',
      externalName: 'Product Sales',
    })

    expect(result).toBe(`456${OPTION_VALUE_SEPARATOR}${OPTION_VALUE_SEPARATOR}Product Sales`)
  })

  it('should handle special characters in values', () => {
    const result = stringifyOptionValue({
      externalId: 'ID-123-$',
      externalAccountCode: 'ACC@001',
      externalName: 'Sales & Marketing Revenue',
    })

    expect(result).toBe(
      `ID-123-$${OPTION_VALUE_SEPARATOR}ACC@001${OPTION_VALUE_SEPARATOR}Sales & Marketing Revenue`,
    )
  })

  it('should handle values containing the separator itself', () => {
    const result = stringifyOptionValue({
      externalId: '123:::456',
      externalAccountCode: 'ACC:::001',
      externalName: 'Revenue:::Sales',
    })

    expect(result).toBe(
      `123:::456${OPTION_VALUE_SEPARATOR}ACC:::001${OPTION_VALUE_SEPARATOR}Revenue:::Sales`,
    )
  })

  it('should handle long values', () => {
    const longId = 'a'.repeat(100)
    const longCode = 'b'.repeat(50)
    const longName = 'c'.repeat(200)

    const result = stringifyOptionValue({
      externalId: longId,
      externalAccountCode: longCode,
      externalName: longName,
    })

    expect(result).toBe(
      `${longId}${OPTION_VALUE_SEPARATOR}${longCode}${OPTION_VALUE_SEPARATOR}${longName}`,
    )
  })

  it('should handle numeric-like string values', () => {
    const result = stringifyOptionValue({
      externalId: '00123',
      externalAccountCode: '456.78',
      externalName: '999',
    })

    expect(result).toBe(`00123${OPTION_VALUE_SEPARATOR}456.78${OPTION_VALUE_SEPARATOR}999`)
  })

  it('should handle whitespace in values', () => {
    const result = stringifyOptionValue({
      externalId: '  123  ',
      externalAccountCode: '\tACC001\n',
      externalName: ' Sales Revenue ',
    })

    expect(result).toBe(
      `  123  ${OPTION_VALUE_SEPARATOR}\tACC001\n${OPTION_VALUE_SEPARATOR} Sales Revenue `,
    )
  })

  it('should handle Unicode characters', () => {
    const result = stringifyOptionValue({
      externalId: '123-€',
      externalAccountCode: 'АСС001',
      externalName: 'Ventes 收入',
    })

    expect(result).toBe(`123-€${OPTION_VALUE_SEPARATOR}АСС001${OPTION_VALUE_SEPARATOR}Ventes 收入`)
  })

  it('should maintain order of fields in output', () => {
    const result = stringifyOptionValue({
      externalId: 'FIRST',
      externalAccountCode: 'SECOND',
      externalName: 'THIRD',
    })

    const parts = result.split(OPTION_VALUE_SEPARATOR)

    expect(parts).toHaveLength(3)
    expect(parts[0]).toBe('FIRST')
    expect(parts[1]).toBe('SECOND')
    expect(parts[2]).toBe('THIRD')
  })
})
