import { PASSWORD_VALIDATION_KEYS } from '~/components/form/PasswordValidationHints/PasswordValidationHints'
import { PASSWORD_VALIDATION_ERRORS, validatePassword } from '~/formValidation/zodCustoms'

import {
  googleRegisterValidationSchema,
  signUpDefaultValues,
  signUpValidationSchema,
} from '../validationSchema'

describe('signUpValidationSchema', () => {
  describe('organizationName', () => {
    it('validates a valid organization name', () => {
      const result = signUpValidationSchema.safeParse({
        organizationName: 'Acme Corp',
        email: 'test@example.com',
        password: 'Password1!',
      })

      expect(result.success).toBe(true)
    })

    it('requires organizationName to be non-empty', () => {
      const result = signUpValidationSchema.safeParse({
        organizationName: '',
        email: 'test@example.com',
        password: 'Password1!',
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        expect(result.error.issues[0].path).toEqual(['organizationName'])
        expect(result.error.issues[0].message).toBe('text_620bc4d4269a55014d493f4d')
      }
    })
  })

  describe('email', () => {
    it('validates a valid email', () => {
      const result = signUpValidationSchema.safeParse({
        organizationName: 'Acme Corp',
        email: 'test@example.com',
        password: 'Password1!',
      })

      expect(result.success).toBe(true)
    })

    it('requires email to be non-empty', () => {
      const result = signUpValidationSchema.safeParse({
        organizationName: 'Acme Corp',
        email: '',
        password: 'Password1!',
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        const issue = result.error.issues.find((i) => i.path.includes('email'))

        expect(issue?.message).toBe('text_620bc4d4269a55014d493f3d')
      }
    })

    it('rejects invalid email format', () => {
      const result = signUpValidationSchema.safeParse({
        organizationName: 'Acme Corp',
        email: 'not-an-email',
        password: 'Password1!',
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        const issue = result.error.issues.find((i) => i.path.includes('email'))

        expect(issue?.message).toBe('text_620bc4d4269a55014d493fc3')
      }
    })

    it('validates various valid email formats', () => {
      const validEmails = [
        'user@domain.com',
        'user.name@domain.com',
        'user+tag@domain.com',
        'user@subdomain.domain.com',
      ]

      validEmails.forEach((email) => {
        const result = signUpValidationSchema.safeParse({
          organizationName: 'Acme Corp',
          email,
          password: 'Password1!',
        })

        expect(result.success).toBe(true)
      })
    })
  })

  describe('password', () => {
    it('validates a valid password with all requirements met', () => {
      const result = signUpValidationSchema.safeParse({
        organizationName: 'Acme Corp',
        email: 'test@example.com',
        password: 'Password1!',
      })

      expect(result.success).toBe(true)
    })

    it('requires password to be non-empty', () => {
      const result = signUpValidationSchema.safeParse({
        organizationName: 'Acme Corp',
        email: 'test@example.com',
        password: '',
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        const issue = result.error.issues.find((i) => i.path.includes('password'))

        expect(issue?.message).toBe(PASSWORD_VALIDATION_ERRORS.REQUIRED)
      }
    })

    it('rejects password shorter than 8 characters', () => {
      const result = signUpValidationSchema.safeParse({
        organizationName: 'Acme Corp',
        email: 'test@example.com',
        password: 'Pass1!',
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        const issue = result.error.issues.find((i) => i.path.includes('password'))

        expect(issue?.message).toBe(PASSWORD_VALIDATION_ERRORS.MIN)
      }
    })

    it('rejects password without lowercase letter', () => {
      const result = signUpValidationSchema.safeParse({
        organizationName: 'Acme Corp',
        email: 'test@example.com',
        password: 'PASSWORD1!',
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        const issue = result.error.issues.find((i) => i.path.includes('password'))

        expect(issue?.message).toBe(PASSWORD_VALIDATION_ERRORS.LOWERCASE)
      }
    })

    it('rejects password without uppercase letter', () => {
      const result = signUpValidationSchema.safeParse({
        organizationName: 'Acme Corp',
        email: 'test@example.com',
        password: 'password1!',
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        const issue = result.error.issues.find((i) => i.path.includes('password'))

        expect(issue?.message).toBe(PASSWORD_VALIDATION_ERRORS.UPPERCASE)
      }
    })

    it('rejects password without number', () => {
      const result = signUpValidationSchema.safeParse({
        organizationName: 'Acme Corp',
        email: 'test@example.com',
        password: 'Password!',
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        const issue = result.error.issues.find((i) => i.path.includes('password'))

        expect(issue?.message).toBe(PASSWORD_VALIDATION_ERRORS.NUMBER)
      }
    })

    it('rejects password without special character', () => {
      const result = signUpValidationSchema.safeParse({
        organizationName: 'Acme Corp',
        email: 'test@example.com',
        password: 'Password1',
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        const issue = result.error.issues.find((i) => i.path.includes('password'))

        expect(issue?.message).toBe(PASSWORD_VALIDATION_ERRORS.SPECIAL)
      }
    })

    it('accepts various valid special characters', () => {
      const specialChars = ['!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '.', ',', '?', '/']

      specialChars.forEach((char) => {
        const result = signUpValidationSchema.safeParse({
          organizationName: 'Acme Corp',
          email: 'test@example.com',
          password: `Password1${char}`,
        })

        expect(result.success).toBe(true)
      })
    })
  })

  describe('full form validation', () => {
    it('validates a complete valid form', () => {
      const result = signUpValidationSchema.safeParse({
        organizationName: 'Acme Corporation',
        email: 'admin@acme.com',
        password: 'SecureP@ss123',
      })

      expect(result.success).toBe(true)
    })

    it('returns multiple errors for invalid form', () => {
      const result = signUpValidationSchema.safeParse({
        organizationName: '',
        email: 'invalid',
        password: 'weak',
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        expect(result.error.issues.length).toBeGreaterThan(1)
      }
    })
  })
})

describe('googleRegisterValidationSchema', () => {
  it('validates with organizationName and empty email/password', () => {
    const result = googleRegisterValidationSchema.safeParse({
      organizationName: 'Acme Corp',
      email: '',
      password: '',
    })

    expect(result.success).toBe(true)
  })

  it('requires organizationName to be non-empty', () => {
    const result = googleRegisterValidationSchema.safeParse({
      organizationName: '',
      email: '',
      password: '',
    })

    expect(result.success).toBe(false)
    if (!result.success) {
      expect(result.error.issues[0].path).toEqual(['organizationName'])
      expect(result.error.issues[0].message).toBe('text_620bc4d4269a55014d493f4d')
    }
  })

  it('does not require email format validation', () => {
    const result = googleRegisterValidationSchema.safeParse({
      organizationName: 'Acme Corp',
      email: 'any-string-is-fine',
      password: '',
    })

    expect(result.success).toBe(true)
  })

  it('does not require password strength validation', () => {
    const result = googleRegisterValidationSchema.safeParse({
      organizationName: 'Acme Corp',
      email: '',
      password: 'weak',
    })

    expect(result.success).toBe(true)
  })

  it('has same shape as signUpValidationSchema for type compatibility', () => {
    const validForm = {
      organizationName: 'Acme Corp',
      email: 'test@example.com',
      password: 'Password1!',
    }

    const signUpResult = signUpValidationSchema.safeParse(validForm)
    const googleResult = googleRegisterValidationSchema.safeParse(validForm)

    expect(signUpResult.success).toBe(true)
    expect(googleResult.success).toBe(true)
  })
})

describe('validatePassword', () => {
  it('returns empty array for valid password', () => {
    expect(validatePassword('Password1!')).toEqual([])
  })

  it('returns MIN error for short password', () => {
    expect(validatePassword('Pass1!')).toContain(PASSWORD_VALIDATION_ERRORS.MIN)
  })

  it('returns LOWERCASE error for password without lowercase', () => {
    expect(validatePassword('PASSWORD1!')).toContain(PASSWORD_VALIDATION_ERRORS.LOWERCASE)
  })

  it('returns UPPERCASE error for password without uppercase', () => {
    expect(validatePassword('password1!')).toContain(PASSWORD_VALIDATION_ERRORS.UPPERCASE)
  })

  it('returns NUMBER error for password without number', () => {
    expect(validatePassword('Password!')).toContain(PASSWORD_VALIDATION_ERRORS.NUMBER)
  })

  it('returns SPECIAL error for password without special character', () => {
    expect(validatePassword('Password1')).toContain(PASSWORD_VALIDATION_ERRORS.SPECIAL)
  })

  it('returns multiple errors for password failing multiple requirements', () => {
    const errors = validatePassword('weak')

    expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.MIN)
    expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.UPPERCASE)
    expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.NUMBER)
    expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.SPECIAL)
  })

  it('does not include REQUIRED error (handled separately by Zod min)', () => {
    const errors = validatePassword('')

    expect(errors).not.toContain(PASSWORD_VALIDATION_ERRORS.REQUIRED)
  })
})

describe('PASSWORD_VALIDATION_ERRORS', () => {
  it('contains all expected error keys', () => {
    expect(PASSWORD_VALIDATION_ERRORS.REQUIRED).toBe('text_620bc4d4269a55014d493f61')
    expect(PASSWORD_VALIDATION_ERRORS.LOWERCASE).toBe('text_620bc4d4269a55014d493f57')
    expect(PASSWORD_VALIDATION_ERRORS.UPPERCASE).toBe('text_620bc4d4269a55014d493f7b')
    expect(PASSWORD_VALIDATION_ERRORS.NUMBER).toBe('text_620bc4d4269a55014d493f8d')
    expect(PASSWORD_VALIDATION_ERRORS.SPECIAL).toBe('text_620bc4d4269a55014d493fa0')
    expect(PASSWORD_VALIDATION_ERRORS.MIN).toBe('text_620bc4d4269a55014d493fac')
  })
})

describe('PASSWORD_VALIDATION_KEYS', () => {
  it('contains only UI display validation keys (excludes REQUIRED)', () => {
    expect(PASSWORD_VALIDATION_KEYS).toHaveLength(5)
    expect(PASSWORD_VALIDATION_KEYS).not.toContain(PASSWORD_VALIDATION_ERRORS.REQUIRED)
    expect(PASSWORD_VALIDATION_KEYS).toContain(PASSWORD_VALIDATION_ERRORS.MIN)
    expect(PASSWORD_VALIDATION_KEYS).toContain(PASSWORD_VALIDATION_ERRORS.LOWERCASE)
    expect(PASSWORD_VALIDATION_KEYS).toContain(PASSWORD_VALIDATION_ERRORS.UPPERCASE)
    expect(PASSWORD_VALIDATION_KEYS).toContain(PASSWORD_VALIDATION_ERRORS.NUMBER)
    expect(PASSWORD_VALIDATION_KEYS).toContain(PASSWORD_VALIDATION_ERRORS.SPECIAL)
  })
})

describe('signUpDefaultValues', () => {
  it('has correct default values', () => {
    expect(signUpDefaultValues).toEqual({
      organizationName: '',
      email: '',
      password: '',
    })
  })
})
