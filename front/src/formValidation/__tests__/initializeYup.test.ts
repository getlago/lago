import { string } from 'yup'

import { initializeYup } from '../initializeYup'

beforeAll(() => {
  initializeYup()
})

describe('initializeYup', () => {
  describe('email validation', () => {
    it('should validate valid email addresses', async () => {
      const schema = string().email('Invalid email')

      const validEmails = [
        'test@example.com',
        'user.name@domain.com',
        'user+tag@example.org',
        'test123@example-domain.com',
        'email@subdomain.example.com',
      ]

      for (const email of validEmails) {
        await expect(schema.validate(email)).resolves.toBe(email)
      }
    })

    it('should reject invalid email addresses', async () => {
      const schema = string().email('Invalid email')

      const invalidEmails = [
        'invalid-email',
        '@example.com',
        'test@',
        'test..test@example.com',
        'test@example',
        'test @example.com',
        'this isatest@example.com',
      ]

      for (const email of invalidEmails) {
        await expect(schema.validate(email)).rejects.toThrow('Invalid email')
      }
    })

    it('should allow empty strings when excludeEmptyString is true', async () => {
      const schema = string().email('Invalid email')

      await expect(schema.validate('')).resolves.toBe('')
    })
  })

  describe('emails validation', () => {
    it('should validate valid comma-separated emails', async () => {
      const schema = string().emails('Invalid emails')

      const validEmailStrings = [
        'test@example.com',
        'test@example.com, another@example.com',
        'test@example.com,another@example.com,third@example.com',
        'test@example.com, another@example.com, third@example.com',
        '  test@example.com  ,  another@example.com  ',
      ]

      for (const emails of validEmailStrings) {
        await expect(schema.validate(emails)).resolves.toBe(emails)
      }
    })

    it('should reject strings with invalid emails', async () => {
      const schema = string().emails('Invalid emails')

      const invalidEmailStrings = [
        'test@example.com, invalid-email',
        'valid@example.com, @invalid.com',
        'test@example.com, another@, third@example.com',
        'test@example.com, test..test@example.com',
        'test@example.com, this isatest@example.com',
      ]

      for (const emails of invalidEmailStrings) {
        await expect(schema.validate(emails)).rejects.toThrow('Invalid emails')
      }
    })

    it('should handle empty and whitespace strings', async () => {
      const schema = string().emails('Invalid emails')

      await expect(schema.validate('')).resolves.toBe('')
      await expect(schema.validate('   ')).resolves.toBe('   ')
    })

    it('should handle single email addresses', async () => {
      const schema = string().emails('Invalid emails')

      await expect(schema.validate('test@example.com')).resolves.toBe('test@example.com')
      await expect(schema.validate('invalid-email')).rejects.toThrow('Invalid emails')
    })

    it('should trim whitespace around individual emails', async () => {
      const schema = string().emails('Invalid emails')

      // This should pass because emails are trimmed before validation
      await expect(schema.validate('  test@example.com  ,  another@example.com  ')).resolves.toBe(
        '  test@example.com  ,  another@example.com  ',
      )
    })
  })

  describe('domain validation', () => {
    it('should validate valid domain names', async () => {
      const schema = string().domain('Invalid domain')

      const validDomains = [
        'example.com',
        'subdomain.example.com',
        'test-domain.org',
        'my-site.co.uk',
        'ai--example.com',
        'example-.com',
        'example.com-',
      ]

      for (const domain of validDomains) {
        await expect(schema.validate(domain)).resolves.toBe(domain)
      }
    })

    it('should reject invalid domain names', async () => {
      const schema = string().domain('Invalid domain')

      const invalidDomains = [
        'invalid-domain',
        '-example.com',
        'example..com',
        '.example.com',
        'example.com.',
      ]

      for (const domain of invalidDomains) {
        await expect(schema.validate(domain)).rejects.toThrow('Invalid domain')
      }
    })

    it('should allow empty strings when excludeEmptyString is true', async () => {
      const schema = string().domain('Invalid domain')

      await expect(schema.validate('')).resolves.toBe('')
    })
  })
})
