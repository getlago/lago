import { renderHook } from '@testing-library/react'

import { PASSWORD_VALIDATION_ERRORS } from '~/formValidation/zodCustoms'

import { usePasswordValidation } from '../usePasswordValidation'

describe('usePasswordValidation', () => {
  describe('with empty password', () => {
    it('returns all validation errors', () => {
      const { result } = renderHook(() => usePasswordValidation(''))

      expect(result.current.isValid).toBe(false)
      expect(result.current.errors).toContain(PASSWORD_VALIDATION_ERRORS.MIN)
      expect(result.current.errors).toContain(PASSWORD_VALIDATION_ERRORS.LOWERCASE)
      expect(result.current.errors).toContain(PASSWORD_VALIDATION_ERRORS.UPPERCASE)
      expect(result.current.errors).toContain(PASSWORD_VALIDATION_ERRORS.NUMBER)
      expect(result.current.errors).toContain(PASSWORD_VALIDATION_ERRORS.SPECIAL)
    })
  })

  describe('with valid password', () => {
    it('returns no errors for a fully valid password', () => {
      const { result } = renderHook(() => usePasswordValidation('Password1!'))

      expect(result.current.isValid).toBe(true)
      expect(result.current.errors).toHaveLength(0)
    })

    it('validates password with various special characters', () => {
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
        const { result } = renderHook(() => usePasswordValidation(password))

        expect(result.current.isValid).toBe(true)
      })
    })
  })

  describe('minimum length validation', () => {
    it('fails for password shorter than 8 characters', () => {
      const { result } = renderHook(() => usePasswordValidation('Pass1!'))

      expect(result.current.isValid).toBe(false)
      expect(result.current.errors).toContain(PASSWORD_VALIDATION_ERRORS.MIN)
    })

    it('passes for password with exactly 8 characters', () => {
      const { result } = renderHook(() => usePasswordValidation('Passwo1!'))

      expect(result.current.isValid).toBe(true)
      expect(result.current.errors).not.toContain(PASSWORD_VALIDATION_ERRORS.MIN)
    })

    it('passes for password longer than 8 characters', () => {
      const { result } = renderHook(() => usePasswordValidation('LongPassword123!'))

      expect(result.current.isValid).toBe(true)
    })
  })

  describe('lowercase validation', () => {
    it('fails for password without lowercase letters', () => {
      const { result } = renderHook(() => usePasswordValidation('PASSWORD1!'))

      expect(result.current.isValid).toBe(false)
      expect(result.current.errors).toContain(PASSWORD_VALIDATION_ERRORS.LOWERCASE)
    })

    it('passes for password with lowercase letters', () => {
      const { result } = renderHook(() => usePasswordValidation('Password1!'))

      expect(result.current.isValid).toBe(true)
      expect(result.current.errors).not.toContain(PASSWORD_VALIDATION_ERRORS.LOWERCASE)
    })
  })

  describe('uppercase validation', () => {
    it('fails for password without uppercase letters', () => {
      const { result } = renderHook(() => usePasswordValidation('password1!'))

      expect(result.current.isValid).toBe(false)
      expect(result.current.errors).toContain(PASSWORD_VALIDATION_ERRORS.UPPERCASE)
    })

    it('passes for password with uppercase letters', () => {
      const { result } = renderHook(() => usePasswordValidation('Password1!'))

      expect(result.current.isValid).toBe(true)
      expect(result.current.errors).not.toContain(PASSWORD_VALIDATION_ERRORS.UPPERCASE)
    })
  })

  describe('number validation', () => {
    it('fails for password without numbers', () => {
      const { result } = renderHook(() => usePasswordValidation('Password!'))

      expect(result.current.isValid).toBe(false)
      expect(result.current.errors).toContain(PASSWORD_VALIDATION_ERRORS.NUMBER)
    })

    it('passes for password with numbers', () => {
      const { result } = renderHook(() => usePasswordValidation('Password1!'))

      expect(result.current.isValid).toBe(true)
      expect(result.current.errors).not.toContain(PASSWORD_VALIDATION_ERRORS.NUMBER)
    })

    it('accepts any digit', () => {
      const passwords = ['Password0!', 'Password5!', 'Password9!']

      passwords.forEach((password) => {
        const { result } = renderHook(() => usePasswordValidation(password))

        expect(result.current.errors).not.toContain(PASSWORD_VALIDATION_ERRORS.NUMBER)
      })
    })
  })

  describe('special character validation', () => {
    it('fails for password without special characters', () => {
      const { result } = renderHook(() => usePasswordValidation('Password1'))

      expect(result.current.isValid).toBe(false)
      expect(result.current.errors).toContain(PASSWORD_VALIDATION_ERRORS.SPECIAL)
    })

    it('passes for password with special characters', () => {
      const { result } = renderHook(() => usePasswordValidation('Password1!'))

      expect(result.current.isValid).toBe(true)
      expect(result.current.errors).not.toContain(PASSWORD_VALIDATION_ERRORS.SPECIAL)
    })
  })

  describe('multiple validation failures', () => {
    it('returns multiple errors for password missing multiple requirements', () => {
      const { result } = renderHook(() => usePasswordValidation('short'))

      expect(result.current.isValid).toBe(false)
      expect(result.current.errors).toContain(PASSWORD_VALIDATION_ERRORS.MIN)
      expect(result.current.errors).toContain(PASSWORD_VALIDATION_ERRORS.UPPERCASE)
      expect(result.current.errors).toContain(PASSWORD_VALIDATION_ERRORS.NUMBER)
      expect(result.current.errors).toContain(PASSWORD_VALIDATION_ERRORS.SPECIAL)
    })

    it('returns only missing requirement errors', () => {
      const { result } = renderHook(() => usePasswordValidation('longpassword'))

      expect(result.current.errors).not.toContain(PASSWORD_VALIDATION_ERRORS.MIN)
      expect(result.current.errors).not.toContain(PASSWORD_VALIDATION_ERRORS.LOWERCASE)
      expect(result.current.errors).toContain(PASSWORD_VALIDATION_ERRORS.UPPERCASE)
      expect(result.current.errors).toContain(PASSWORD_VALIDATION_ERRORS.NUMBER)
      expect(result.current.errors).toContain(PASSWORD_VALIDATION_ERRORS.SPECIAL)
    })
  })

  describe('memoization', () => {
    it('returns same result object for same password', () => {
      const { result, rerender } = renderHook(({ password }) => usePasswordValidation(password), {
        initialProps: { password: 'Password1!' },
      })

      const firstResult = result.current

      rerender({ password: 'Password1!' })
      const secondResult = result.current

      expect(firstResult).toBe(secondResult)
    })

    it('returns new result object for different password', () => {
      const { result, rerender } = renderHook(({ password }) => usePasswordValidation(password), {
        initialProps: { password: 'Password1!' },
      })

      const firstResult = result.current

      rerender({ password: 'DifferentPassword1!' })
      const secondResult = result.current

      expect(firstResult).not.toBe(secondResult)
    })
  })
})
