import { ResourceTypeEnum } from '~/generated/graphql'

import { isEmailActivity } from '../typeguards'

describe('activityLogs typeguards', () => {
  describe('isEmailActivity', () => {
    it('should return true for valid email activity object', () => {
      const validEmailActivity = {
        document: {
          lago_id: 'invoice-123',
          number: 'INV-001',
          type: ResourceTypeEnum.Invoice,
        },
      }

      expect(isEmailActivity(validEmailActivity)).toBe(true)
    })

    it('should return true for valid email activity with different resource type', () => {
      const validEmailActivity = {
        document: {
          lago_id: 'credit-note-456',
          number: 'CN-002',
          type: ResourceTypeEnum.CreditNote,
        },
      }

      expect(isEmailActivity(validEmailActivity)).toBe(true)
    })

    it('should return false when document is missing', () => {
      const invalidActivity = {}

      expect(isEmailActivity(invalidActivity)).toBe(false)
    })

    it('should return false when document is not an object', () => {
      const invalidActivity = {
        document: 'not an object',
      }

      expect(isEmailActivity(invalidActivity)).toBe(false)
    })

    it('should return false when document is null', () => {
      const invalidActivity = {
        document: null,
      }

      expect(isEmailActivity(invalidActivity)).toBe(false)
    })

    it('should return false when lago_id is missing', () => {
      const invalidActivity = {
        document: {
          number: 'INV-001',
          type: ResourceTypeEnum.Invoice,
        },
      }

      expect(isEmailActivity(invalidActivity)).toBe(false)
    })

    it('should return false when lago_id is not a string', () => {
      const invalidActivity = {
        document: {
          lago_id: 123,
          number: 'INV-001',
          type: ResourceTypeEnum.Invoice,
        },
      }

      expect(isEmailActivity(invalidActivity)).toBe(false)
    })

    it('should return false when number is missing', () => {
      const invalidActivity = {
        document: {
          lago_id: 'invoice-123',
          type: ResourceTypeEnum.Invoice,
        },
      }

      expect(isEmailActivity(invalidActivity)).toBe(false)
    })

    it('should return false when number is not a string', () => {
      const invalidActivity = {
        document: {
          lago_id: 'invoice-123',
          number: 123,
          type: ResourceTypeEnum.Invoice,
        },
      }

      expect(isEmailActivity(invalidActivity)).toBe(false)
    })

    it('should return false when type is missing', () => {
      const invalidActivity = {
        document: {
          lago_id: 'invoice-123',
          number: 'INV-001',
        },
      }

      expect(isEmailActivity(invalidActivity)).toBe(false)
    })

    it('should return false when type is not a string', () => {
      const invalidActivity = {
        document: {
          lago_id: 'invoice-123',
          number: 'INV-001',
          type: 123,
        },
      }

      expect(isEmailActivity(invalidActivity)).toBe(false)
    })

    it('should return false for empty object', () => {
      expect(isEmailActivity({})).toBe(false)
    })

    it('should return false when document has extra properties but missing required ones', () => {
      const invalidActivity = {
        document: {
          lago_id: 'invoice-123',
          extraProperty: 'value',
        },
      }

      expect(isEmailActivity(invalidActivity)).toBe(false)
    })
  })
})
