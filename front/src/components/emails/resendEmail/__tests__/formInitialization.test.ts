import {
  resendEmailFormDefaultValues,
  ResendEmailFormDefaultValues,
  resendEmailFormValidationSchema,
} from '~/components/emails/resendEmail/formInitialization'

describe('formInitialization', () => {
  describe('resendEmailFormDefaultValues', () => {
    it('has correct default values for all fields', () => {
      expect(resendEmailFormDefaultValues).toEqual({
        to: [],
        cc: undefined,
        bcc: undefined,
      })
    })

    it('matches ResendEmailFormDefaultValues type', () => {
      const values: ResendEmailFormDefaultValues = resendEmailFormDefaultValues

      expect(values).toBeDefined()
    })
  })

  describe('resendEmailFormValidationSchema', () => {
    it('validates correct email format in to field', () => {
      const validData = {
        to: [{ value: 'test@example.com' }],
      }

      const result = resendEmailFormValidationSchema.safeParse(validData)

      expect(result.success).toBe(true)
    })

    it('validates correct email format in cc field', () => {
      const validData = {
        to: [{ value: 'to@example.com' }],
        cc: [{ value: 'test@example.com' }],
      }

      const result = resendEmailFormValidationSchema.safeParse(validData)

      expect(result.success).toBe(true)
    })

    it('validates correct email format in bcc field', () => {
      const validData = {
        to: [{ value: 'to@example.com' }],
        bcc: [{ value: 'test@example.com' }],
      }

      const result = resendEmailFormValidationSchema.safeParse(validData)

      expect(result.success).toBe(true)
    })

    it('rejects invalid email format in to field', () => {
      const invalidData = {
        to: [{ value: 'invalid-email' }],
      }

      const result = resendEmailFormValidationSchema.safeParse(invalidData)

      expect(result.success).toBe(false)
    })

    it('rejects invalid email format in cc field', () => {
      const invalidData = {
        cc: [{ value: 'invalid-email' }],
      }

      const result = resendEmailFormValidationSchema.safeParse(invalidData)

      expect(result.success).toBe(false)
    })

    it('rejects invalid email format in bcc field', () => {
      const invalidData = {
        bcc: [{ value: 'invalid-email' }],
      }

      const result = resendEmailFormValidationSchema.safeParse(invalidData)

      expect(result.success).toBe(false)
    })

    it('accepts multiple valid emails in to field', () => {
      const validData = {
        to: [{ value: 'test1@example.com' }, { value: 'test2@example.com' }],
      }

      const result = resendEmailFormValidationSchema.safeParse(validData)

      expect(result.success).toBe(true)
    })

    it('accepts multiple valid emails in cc field', () => {
      const validData = {
        to: [{ value: 'to@example.com' }],
        cc: [{ value: 'test1@example.com' }, { value: 'test2@example.com' }],
      }

      const result = resendEmailFormValidationSchema.safeParse(validData)

      expect(result.success).toBe(true)
    })

    it('accepts multiple valid emails in bcc field', () => {
      const validData = {
        to: [{ value: 'to@example.com' }],
        bcc: [{ value: 'test1@example.com' }, { value: 'test2@example.com' }],
      }

      const result = resendEmailFormValidationSchema.safeParse(validData)

      expect(result.success).toBe(true)
    })

    it('accepts undefined values for optional fields', () => {
      const validData = {
        to: [{ value: 'to@example.com' }],
        cc: undefined,
        bcc: undefined,
      }

      const result = resendEmailFormValidationSchema.safeParse(validData)

      expect(result.success).toBe(true)
    })

    it('rejects empty to field', () => {
      const validData = {
        to: [],
      }

      const result = resendEmailFormValidationSchema.safeParse(validData)

      expect(result.success).toBe(false)
    })

    it('validates all fields together with mixed valid emails', () => {
      const validData = {
        to: [{ value: 'to@example.com' }],
        cc: [{ value: 'cc@example.com' }],
        bcc: [{ value: 'bcc@example.com' }],
      }

      const result = resendEmailFormValidationSchema.safeParse(validData)

      expect(result.success).toBe(true)
    })

    it('rejects when one field has invalid email among valid ones', () => {
      const invalidData = {
        to: [{ value: 'valid@example.com' }],
        cc: [{ value: 'invalid-email' }],
        bcc: [{ value: 'valid@example.com' }],
      }

      const result = resendEmailFormValidationSchema.safeParse(invalidData)

      expect(result.success).toBe(false)
    })
  })
})
