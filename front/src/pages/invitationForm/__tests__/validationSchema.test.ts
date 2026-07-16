import { PASSWORD_VALIDATION_ERRORS } from '~/formValidation/zodCustoms'

import {
  invitationDefaultValues,
  InvitationFormValues,
  invitationValidationSchema,
} from '../validationSchema'

describe('invitationValidationSchema', () => {
  describe('password validation', () => {
    it('should fail for empty password', () => {
      const result = invitationValidationSchema.safeParse({ password: '' })

      expect(result.success).toBe(false)
      if (!result.success) {
        const errors = result.error.flatten().fieldErrors.password

        expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.REQUIRED)
      }
    })

    it('should fail for password shorter than 8 characters', () => {
      const result = invitationValidationSchema.safeParse({ password: 'Pass1!' })

      expect(result.success).toBe(false)
      if (!result.success) {
        const errors = result.error.flatten().fieldErrors.password

        expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.MIN)
      }
    })

    it('should fail for password without lowercase letters', () => {
      const result = invitationValidationSchema.safeParse({ password: 'PASSWORD1!' })

      expect(result.success).toBe(false)
      if (!result.success) {
        const errors = result.error.flatten().fieldErrors.password

        expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.LOWERCASE)
      }
    })

    it('should fail for password without uppercase letters', () => {
      const result = invitationValidationSchema.safeParse({ password: 'password1!' })

      expect(result.success).toBe(false)
      if (!result.success) {
        const errors = result.error.flatten().fieldErrors.password

        expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.UPPERCASE)
      }
    })

    it('should fail for password without numbers', () => {
      const result = invitationValidationSchema.safeParse({ password: 'Password!' })

      expect(result.success).toBe(false)
      if (!result.success) {
        const errors = result.error.flatten().fieldErrors.password

        expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.NUMBER)
      }
    })

    it('should fail for password without special characters', () => {
      const result = invitationValidationSchema.safeParse({ password: 'Password1' })

      expect(result.success).toBe(false)
      if (!result.success) {
        const errors = result.error.flatten().fieldErrors.password

        expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.SPECIAL)
      }
    })

    it('should pass for valid password', () => {
      const result = invitationValidationSchema.safeParse({ password: 'Password1!' })

      expect(result.success).toBe(true)
    })

    it('should pass for password with various special characters', () => {
      const validPasswords = [
        'Password1!',
        'Password1@',
        'Password1#',
        'Password1$',
        'Password1%',
        'Password1^',
        'Password1&',
        'Password1*',
        'Password1/',
        'Password1.',
        'Password1,',
        'Password1?',
      ]

      validPasswords.forEach((password) => {
        const result = invitationValidationSchema.safeParse({ password })

        expect(result.success).toBe(true)
      })
    })

    it('should return multiple errors for password missing multiple requirements', () => {
      const result = invitationValidationSchema.safeParse({ password: 'short' })

      expect(result.success).toBe(false)
      if (!result.success) {
        const errors = result.error.flatten().fieldErrors.password || []

        expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.MIN)
        expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.UPPERCASE)
        expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.NUMBER)
        expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.SPECIAL)
      }
    })
  })
})

describe('invitationDefaultValues', () => {
  it('should have empty password as default', () => {
    expect(invitationDefaultValues.password).toBe('')
  })

  it('should match the expected type', () => {
    const values: InvitationFormValues = invitationDefaultValues

    expect(values).toHaveProperty('password')
  })
})
