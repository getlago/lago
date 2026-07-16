import { isItemMapping } from '../isItemMapping'

describe('isItemMapping', () => {
  it('should return true for valid item mapping objects', () => {
    const validItemMapping = {
      id: '123',
      externalId: 'ext-123',
      externalName: 'External Name',
      externalAccountCode: 'AC-456',
    }

    expect(isItemMapping(validItemMapping)).toBe(true)
  })

  it('should return false for invalid item mapping objects', () => {
    const invalidItemMapping1 = {
      externalId: 'ext-123',
      externalName: 'External Name',
    }
    const invalidItemMapping2 = {
      id: 123, // id should be a string
      externalId: 'ext-123',
      externalName: 'External Name',
    }
    const invalidItemMapping3 = null
    const invalidItemMapping4 = 'not an object'

    expect(isItemMapping(invalidItemMapping1)).toBe(false)
    expect(isItemMapping(invalidItemMapping2)).toBe(false)
    expect(isItemMapping(invalidItemMapping3)).toBe(false)
    expect(isItemMapping(invalidItemMapping4)).toBe(false)
  })
})
