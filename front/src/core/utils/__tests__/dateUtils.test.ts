import { DateTime, Settings } from 'luxon'

import { endOfDayIso } from '../dateUtils'

const originalDefaultZone = Settings.defaultZone

describe('dateUtils', () => {
  beforeAll(() => {
    Settings.defaultZone = 'UTC'
  })

  afterAll(() => {
    Settings.defaultZone = originalDefaultZone
  })

  describe('endOfDayIso', () => {
    it('should convert a date string to end of day ISO format', () => {
      const inputDate = '2023-12-15T10:30:00.000Z'
      const result = endOfDayIso(inputDate)

      // The result should be the same date but at the end of the day
      const expected = DateTime.fromISO(inputDate).endOf('day').toISO()

      expect(result).toBe(expected)
    })

    it('should return empty string for null input', () => {
      const result = endOfDayIso(null)

      expect(result).toBe('')
    })

    it('should return empty string for undefined input', () => {
      const result = endOfDayIso(undefined)

      expect(result).toBe('')
    })

    it('should return empty string for empty string input', () => {
      const result = endOfDayIso('')

      expect(result).toBe('')
    })

    it('should handle different date formats', () => {
      const inputDate = '2023-12-15'
      const result = endOfDayIso(inputDate)

      const expected = DateTime.fromISO(inputDate).endOf('day').toISO()

      expect(result).toBe(expected)
    })
  })
})
