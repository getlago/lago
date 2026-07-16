import { OPTION_VALUE_SEPARATOR } from '../const'
import { extractOptionValue } from '../extractOptionValue'

describe('extractOptionValue', () => {
  describe('valid inputs', () => {
    it('should extract all three values when provided with a complete option value', () => {
      const optionValue = `123${OPTION_VALUE_SEPARATOR}ACC001${OPTION_VALUE_SEPARATOR}Sales Revenue`
      const result = extractOptionValue(optionValue)

      expect(result).toEqual({
        externalId: '123',
        externalAccountCode: 'ACC001',
        externalName: 'Sales Revenue',
      })
    })

    it('should handle empty string values correctly', () => {
      const optionValue = `${OPTION_VALUE_SEPARATOR}${OPTION_VALUE_SEPARATOR}`
      const result = extractOptionValue(optionValue)

      expect(result).toEqual({
        externalId: '',
        externalAccountCode: '',
        externalName: '',
      })
    })

    it('should handle mixed empty and non-empty values', () => {
      const optionValue = `123${OPTION_VALUE_SEPARATOR}${OPTION_VALUE_SEPARATOR}Sales Revenue`
      const result = extractOptionValue(optionValue)

      expect(result).toEqual({
        externalId: '123',
        externalAccountCode: '',
        externalName: 'Sales Revenue',
      })
    })

    it('should handle values with special characters', () => {
      const optionValue = `id-123${OPTION_VALUE_SEPARATOR}ACC/001${OPTION_VALUE_SEPARATOR}Sales & Marketing Revenue`
      const result = extractOptionValue(optionValue)

      expect(result).toEqual({
        externalId: 'id-123',
        externalAccountCode: 'ACC/001',
        externalName: 'Sales & Marketing Revenue',
      })
    })

    it('should handle values with spaces', () => {
      const optionValue = `123 456${OPTION_VALUE_SEPARATOR}ACC 001${OPTION_VALUE_SEPARATOR}Sales Revenue Account`
      const result = extractOptionValue(optionValue)

      expect(result).toEqual({
        externalId: '123 456',
        externalAccountCode: 'ACC 001',
        externalName: 'Sales Revenue Account',
      })
    })
  })

  describe('edge cases', () => {
    it('should handle input with only one separator', () => {
      const optionValue = `123${OPTION_VALUE_SEPARATOR}ACC001`
      const result = extractOptionValue(optionValue)

      expect(result).toEqual({
        externalId: '123',
        externalAccountCode: 'ACC001',
        externalName: undefined,
      })
    })

    it('should handle input with no separators', () => {
      const optionValue = '123'
      const result = extractOptionValue(optionValue)

      expect(result).toEqual({
        externalId: '123',
        externalAccountCode: undefined,
        externalName: undefined,
      })
    })

    it('should handle empty string input', () => {
      const optionValue = ''
      const result = extractOptionValue(optionValue)

      expect(result).toEqual({
        externalId: undefined,
        externalAccountCode: undefined,
        externalName: undefined,
      })
    })

    it('should handle input with extra separators', () => {
      const optionValue = `123${OPTION_VALUE_SEPARATOR}ACC001${OPTION_VALUE_SEPARATOR}Sales Revenue${OPTION_VALUE_SEPARATOR}Extra Data`
      const result = extractOptionValue(optionValue)

      expect(result).toEqual({
        externalId: '123',
        externalAccountCode: 'ACC001',
        externalName: 'Sales Revenue',
      })
    })

    it('should handle input with extra separators by taking only first three parts', () => {
      const optionValue = `123${OPTION_VALUE_SEPARATOR}ACC${OPTION_VALUE_SEPARATOR}001${OPTION_VALUE_SEPARATOR}Sales${OPTION_VALUE_SEPARATOR}Revenue`
      const result = extractOptionValue(optionValue)

      expect(result).toEqual({
        externalId: '123',
        externalAccountCode: 'ACC',
        externalName: '001',
      })
    })
  })

  describe('numeric values', () => {
    it('should handle numeric IDs and codes', () => {
      const optionValue = `12345${OPTION_VALUE_SEPARATOR}67890${OPTION_VALUE_SEPARATOR}Account Name`
      const result = extractOptionValue(optionValue)

      expect(result).toEqual({
        externalId: '12345',
        externalAccountCode: '67890',
        externalName: 'Account Name',
      })
    })
  })

  describe('unicode and international characters', () => {
    it('should handle unicode characters in values', () => {
      const optionValue = `123${OPTION_VALUE_SEPARATOR}ACC001${OPTION_VALUE_SEPARATOR}Véntes et Märketing`
      const result = extractOptionValue(optionValue)

      expect(result).toEqual({
        externalId: '123',
        externalAccountCode: 'ACC001',
        externalName: 'Véntes et Märketing',
      })
    })

    it('should handle emoji and special unicode characters', () => {
      const optionValue = `🎯123${OPTION_VALUE_SEPARATOR}💰ACC001${OPTION_VALUE_SEPARATOR}Sales 📈 Revenue`
      const result = extractOptionValue(optionValue)

      expect(result).toEqual({
        externalId: '🎯123',
        externalAccountCode: '💰ACC001',
        externalName: 'Sales 📈 Revenue',
      })
    })
  })
})
