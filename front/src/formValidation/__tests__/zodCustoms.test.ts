import {
  PASSWORD_VALIDATION_ERRORS,
  validatePassword,
  zodDomain,
  zodHost,
  zodMultipleEmails,
  zodOneOfPermissions,
  zodOptionalHost,
  zodOptionalUrl,
  zodRequiredEmail,
  zodRequiredPassword,
} from '~/formValidation/zodCustoms'

describe('zodCustoms', () => {
  describe('zodMultipleEmails', () => {
    describe('valid', () => {
      it.each([
        ['user@example.com', 'single email'],
        ['user@example.com, admin@test.org', 'two emails'],
        ['a@b.co, c@d.io, e@f.com', 'three emails'],
        ['user+tag@example.com', 'email with plus'],
        ['', 'empty string (optional)'],
      ])('accepts "%s" (%s)', (value) => {
        const result = zodMultipleEmails.safeParse(value)

        expect(result.success).toBe(true)
      })
    })

    describe('invalid', () => {
      it.each([
        ['not-an-email', 'plain string'],
        ['user@', 'missing domain'],
        ['@example.com', 'missing local part'],
        ['user@example.com, bad-email', 'one valid and one invalid'],
        ['user@example.com,,another@test.com', 'double comma produces empty entry'],
      ])('rejects "%s" (%s)', (value) => {
        const result = zodMultipleEmails.safeParse(value)

        expect(result.success).toBe(false)
      })
    })

    describe('error message', () => {
      it('returns the correct error key on failure', () => {
        const result = zodMultipleEmails.safeParse('invalid')

        expect(result.success).toBe(false)

        if (!result.success) {
          expect(result.error.issues[0].message).toBe('text_620bc4d4269a55014d493fc3')
        }
      })
    })
  })

  describe('zodDomain', () => {
    describe('valid', () => {
      it.each([
        ['example.com', 'simple domain'],
        ['sub.example.com', 'subdomain'],
        ['example.co.uk', 'multi-part TLD'],
        ['test-domain.org', 'hyphen in domain'],
        ['xn--nxasmq6b.com', 'internationalized domain (punycode)'],
        ['a1.io', 'short domain with number'],
      ])('accepts "%s" (%s)', (value) => {
        const result = zodDomain.safeParse(value)

        expect(result.success).toBe(true)
      })
    })

    describe('invalid', () => {
      it.each([
        ['', 'empty string'],
        ['-example.com', 'starts with hyphen'],
        ['example', 'no TLD'],
        ['http://example.com', 'has protocol'],
        ['example.com/path', 'has path'],
        ['example .com', 'contains space'],
      ])('rejects "%s" (%s)', (value) => {
        const result = zodDomain.safeParse(value)

        expect(result.success).toBe(false)
      })
    })

    describe('error message', () => {
      it('returns the correct error key on failure', () => {
        const result = zodDomain.safeParse('invalid')

        expect(result.success).toBe(false)

        if (!result.success) {
          expect(result.error.issues[0].message).toBe('text_664c732c264d7eed1c74fe03')
        }
      })
    })
  })

  describe('zodHost', () => {
    describe('valid', () => {
      it.each([
        ['example.com', 'simple domain'],
        ['subdomain.example.com', 'subdomain'],
        ['deep.subdomain.example.com', 'deep subdomain'],
        ['test-domain.org', 'domain with hyphen'],
        ['example.co.uk', 'multi-part TLD'],
        ['192.168.1.1', 'IPv4 address'],
        ['10.0.0.1', 'private IPv4'],
        ['255.255.255.255', 'max IPv4'],
        ['0.0.0.0', 'zero IPv4'],
        ['::1', 'IPv6 loopback'],
        ['::', 'IPv6 unspecified'],
        ['2001:0db8:85a3:0000:0000:8a2e:0370:7334', 'full IPv6'],
        ['example.com:8080', 'domain with port'],
        ['subdomain.example.com:3000', 'subdomain with port'],
        ['192.168.1.1:443', 'IPv4 with port'],
      ])('accepts "%s" (%s)', (value) => {
        const result = zodHost.safeParse(value)

        expect(result.success).toBe(true)
      })
    })

    describe('invalid', () => {
      it.each([
        ['http://example.com', 'http protocol'],
        ['https://example.com', 'https protocol'],
        ['HTTP://EXAMPLE.COM', 'uppercase http protocol'],
        ['HTTPS://EXAMPLE.COM', 'uppercase https protocol'],
        ['http://192.168.1.1', 'http with IP'],
        ['https://192.168.1.1:8080', 'https with IP and port'],
        ['not a host', 'contains spaces'],
        ['', 'empty string'],
        ['-example.com', 'starts with hyphen'],
      ])('rejects "%s" (%s)', (value) => {
        const result = zodHost.safeParse(value)

        expect(result.success).toBe(false)
      })
    })

    describe('error message', () => {
      it('returns the correct error key on failure', () => {
        const result = zodHost.safeParse('https://example.com')

        expect(result.success).toBe(false)

        if (!result.success) {
          expect(result.error.issues[0].message).toBe('text_664c732c264d7eed1c74fdd3')
        }
      })
    })
  })

  describe('zodOptionalHost', () => {
    describe('valid', () => {
      it.each([
        ['', 'empty string (optional)'],
        ['example.com', 'simple domain'],
        ['subdomain.example.com', 'subdomain'],
        ['deep.subdomain.example.com', 'deep subdomain'],
        ['test-domain.org', 'domain with hyphen'],
        ['example.co.uk', 'multi-part TLD'],
        ['192.168.1.1', 'IPv4 address'],
        ['10.0.0.1', 'private IPv4'],
        ['255.255.255.255', 'max IPv4'],
        ['0.0.0.0', 'zero IPv4'],
        ['::1', 'IPv6 loopback'],
        ['::', 'IPv6 unspecified'],
        ['2001:0db8:85a3:0000:0000:8a2e:0370:7334', 'full IPv6'],
        ['example.com:8080', 'domain with port'],
        ['subdomain.example.com:3000', 'subdomain with port'],
        ['192.168.1.1:443', 'IPv4 with port'],
      ])('accepts "%s" (%s)', (value) => {
        const result = zodOptionalHost.safeParse(value)

        expect(result.success).toBe(true)
      })
    })

    describe('invalid', () => {
      it.each([
        ['http://example.com', 'http protocol'],
        ['https://example.com', 'https protocol'],
        ['HTTP://EXAMPLE.COM', 'uppercase http protocol'],
        ['HTTPS://EXAMPLE.COM', 'uppercase https protocol'],
        ['http://192.168.1.1', 'http with IP'],
        ['https://192.168.1.1:8080', 'https with IP and port'],
        ['not a host', 'contains spaces'],
        ['-example.com', 'starts with hyphen'],
      ])('rejects "%s" (%s)', (value) => {
        const result = zodOptionalHost.safeParse(value)

        expect(result.success).toBe(false)
      })
    })

    describe('error message', () => {
      it('returns the correct error key on failure', () => {
        const result = zodOptionalHost.safeParse('https://example.com')

        expect(result.success).toBe(false)

        if (!result.success) {
          expect(result.error.issues[0].message).toBe('text_664c732c264d7eed1c74fdd3')
        }
      })
    })
  })

  describe('zodOptionalUrl', () => {
    describe('valid', () => {
      it.each([
        ['', 'empty string (optional)'],
        ['https://example.com', 'https URL'],
        ['http://example.com', 'http URL'],
        ['https://example.com/path?query=1', 'URL with path and query'],
        ['https://sub.domain.com:8080/path', 'URL with port and path'],
      ])('accepts "%s" (%s)', (value) => {
        const result = zodOptionalUrl.safeParse(value)

        expect(result.success).toBe(true)
      })
    })

    describe('invalid', () => {
      it.each([
        ['not-a-url', 'plain string'],
        ['example.com', 'missing protocol'],
        ['://missing-scheme.com', 'missing scheme'],
      ])('rejects "%s" (%s)', (value) => {
        const result = zodOptionalUrl.safeParse(value)

        expect(result.success).toBe(false)
      })
    })

    describe('error message', () => {
      it('returns the correct error key on failure', () => {
        const result = zodOptionalUrl.safeParse('invalid')

        expect(result.success).toBe(false)

        if (!result.success) {
          expect(result.error.issues[0].message).toBe('text_1764239804026ca61hwr3pp9')
        }
      })
    })
  })

  describe('zodOneOfPermissions', () => {
    describe('valid', () => {
      it.each([
        ['AddonsCreate', 'AddonsCreate permission'],
        ['AddonsView', 'AddonsView permission'],
        ['AnalyticsView', 'AnalyticsView permission'],
      ])('accepts "%s" (%s)', (value) => {
        const result = zodOneOfPermissions.safeParse(value)

        expect(result.success).toBe(true)
      })
    })

    describe('invalid', () => {
      it.each([
        ['NotAPermission', 'non-existent permission'],
        ['', 'empty string'],
        ['addonsCreate', 'wrong case'],
      ])('rejects "%s" (%s)', (value) => {
        const result = zodOneOfPermissions.safeParse(value)

        expect(result.success).toBe(false)
      })
    })
  })

  describe('zodRequiredEmail', () => {
    describe('valid', () => {
      it.each([
        ['user@example.com', 'simple email'],
        ['user+tag@example.com', 'email with plus'],
        ['name.surname@domain.co.uk', 'email with dots and multi-part TLD'],
        ['u@d.io', 'minimal email'],
      ])('accepts "%s" (%s)', (value) => {
        const result = zodRequiredEmail.safeParse(value)

        expect(result.success).toBe(true)
      })
    })

    describe('invalid', () => {
      it('rejects empty string with required error', () => {
        const result = zodRequiredEmail.safeParse('')

        expect(result.success).toBe(false)

        if (!result.success) {
          expect(result.error.issues[0].message).toBe('text_620bc4d4269a55014d493f3d')
        }
      })

      it.each([
        ['not-an-email', 'plain string'],
        ['user@', 'missing domain'],
        ['@example.com', 'missing local part'],
      ])('rejects "%s" (%s) with format error', (value) => {
        const result = zodRequiredEmail.safeParse(value)

        expect(result.success).toBe(false)

        if (!result.success) {
          expect(result.error.issues[0].message).toBe('text_620bc4d4269a55014d493fc3')
        }
      })
    })
  })

  describe('validatePassword', () => {
    it('returns no errors for a fully valid password', () => {
      expect(validatePassword('MyP@ssw0rd')).toEqual([])
    })

    it('returns MIN error when password is shorter than 8 characters', () => {
      expect(validatePassword('A1a!')).toContain(PASSWORD_VALIDATION_ERRORS.MIN)
    })

    it('returns LOWERCASE error when password has no lowercase letter', () => {
      expect(validatePassword('MYPASSW0RD!')).toContain(PASSWORD_VALIDATION_ERRORS.LOWERCASE)
    })

    it('returns UPPERCASE error when password has no uppercase letter', () => {
      expect(validatePassword('mypassw0rd!')).toContain(PASSWORD_VALIDATION_ERRORS.UPPERCASE)
    })

    it('returns NUMBER error when password has no digit', () => {
      expect(validatePassword('MyPassword!')).toContain(PASSWORD_VALIDATION_ERRORS.NUMBER)
    })

    it('returns SPECIAL error when password has no special character', () => {
      expect(validatePassword('MyPassw0rd')).toContain(PASSWORD_VALIDATION_ERRORS.SPECIAL)
    })

    it('returns multiple errors when multiple rules are violated', () => {
      const errors = validatePassword('abc')

      expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.MIN)
      expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.UPPERCASE)
      expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.NUMBER)
      expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.SPECIAL)
      expect(errors).not.toContain(PASSWORD_VALIDATION_ERRORS.LOWERCASE)
    })

    it('returns all errors for an empty string', () => {
      const errors = validatePassword('')

      expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.MIN)
      expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.LOWERCASE)
      expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.UPPERCASE)
      expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.NUMBER)
      expect(errors).toContain(PASSWORD_VALIDATION_ERRORS.SPECIAL)
    })
  })

  describe('zodRequiredPassword', () => {
    it('accepts a fully valid password', () => {
      const result = zodRequiredPassword.safeParse('MyP@ssw0rd')

      expect(result.success).toBe(true)
    })

    it('rejects empty string with REQUIRED error', () => {
      const result = zodRequiredPassword.safeParse('')

      expect(result.success).toBe(false)

      if (!result.success) {
        expect(result.error.issues[0].message).toBe(PASSWORD_VALIDATION_ERRORS.REQUIRED)
      }
    })

    it('rejects a password missing uppercase with the correct error', () => {
      const result = zodRequiredPassword.safeParse('mypassw0rd!')

      expect(result.success).toBe(false)

      if (!result.success) {
        const messages = result.error.issues.map((i) => i.message)

        expect(messages).toContain(PASSWORD_VALIDATION_ERRORS.UPPERCASE)
      }
    })

    it('reports multiple validation errors at once', () => {
      const result = zodRequiredPassword.safeParse('abc')

      expect(result.success).toBe(false)

      if (!result.success) {
        const messages = result.error.issues.map((i) => i.message)

        expect(messages).toContain(PASSWORD_VALIDATION_ERRORS.MIN)
        expect(messages).toContain(PASSWORD_VALIDATION_ERRORS.UPPERCASE)
        expect(messages).toContain(PASSWORD_VALIDATION_ERRORS.NUMBER)
        expect(messages).toContain(PASSWORD_VALIDATION_ERRORS.SPECIAL)
      }
    })
  })
})
