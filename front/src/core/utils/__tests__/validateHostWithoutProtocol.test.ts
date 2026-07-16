import { validateHostWithoutProtocol } from '../validateHostWithoutProtocol'

describe('validateHostWithoutProtocol', () => {
  describe('protocol rejection', () => {
    it('should reject http:// protocol', () => {
      expect(validateHostWithoutProtocol('http://example.com')).toBe(false)
    })

    it('should reject https:// protocol', () => {
      expect(validateHostWithoutProtocol('https://example.com')).toBe(false)
    })

    it('should reject http:// protocol (case insensitive)', () => {
      expect(validateHostWithoutProtocol('HTTP://example.com')).toBe(false)
    })

    it('should reject https:// protocol (case insensitive)', () => {
      expect(validateHostWithoutProtocol('HTTPS://example.com')).toBe(false)
    })
  })

  describe('valid domain names', () => {
    it('should accept simple domain', () => {
      expect(validateHostWithoutProtocol('example.com')).toBe(true)
    })

    it('should accept subdomain', () => {
      expect(validateHostWithoutProtocol('subdomain.example.com')).toBe(true)
    })

    it('should accept domain with multiple subdomains', () => {
      expect(validateHostWithoutProtocol('sub.subdomain.example.com')).toBe(true)
    })

    it('should accept domain with hyphen', () => {
      expect(validateHostWithoutProtocol('test-domain.com')).toBe(true)
    })
  })

  describe('valid IP addresses', () => {
    it('should accept IPv4 address', () => {
      expect(validateHostWithoutProtocol('192.168.1.1')).toBe(true)
    })

    it('should accept IPv6 address', () => {
      expect(validateHostWithoutProtocol('2001:0db8:85a3:0000:0000:8a2e:0370:7334')).toBe(true)
    })
  })

  describe('valid hosts with ports', () => {
    it('should accept domain with port', () => {
      expect(validateHostWithoutProtocol('example.com:8080')).toBe(true)
    })

    it('should accept subdomain with port', () => {
      expect(validateHostWithoutProtocol('subdomain.example.com:3000')).toBe(true)
    })

    it('should accept IPv4 with port', () => {
      expect(validateHostWithoutProtocol('192.168.1.1:8080')).toBe(true)
    })

    it('should accept localhost IPv4 with port', () => {
      expect(validateHostWithoutProtocol('127.0.0.1:3000')).toBe(true)
    })
  })

  describe('invalid host formats', () => {
    it('should reject domain without TLD', () => {
      expect(validateHostWithoutProtocol('example')).toBe(false)
    })

    it('should reject domain starting with hyphen', () => {
      expect(validateHostWithoutProtocol('-example.com')).toBe(false)
    })

    it('should reject domain with double dots', () => {
      expect(validateHostWithoutProtocol('example..com')).toBe(false)
    })

    it('should reject domain starting with dot', () => {
      expect(validateHostWithoutProtocol('.example.com')).toBe(false)
    })

    it('should reject invalid IPv4', () => {
      expect(validateHostWithoutProtocol('999.999.999.999')).toBe(false)
    })

    it('should reject incomplete IPv4', () => {
      expect(validateHostWithoutProtocol('192.168.1')).toBe(false)
    })

    it('should reject host with path', () => {
      expect(validateHostWithoutProtocol('example.com/path')).toBe(false)
    })

    it('should reject host with query string', () => {
      expect(validateHostWithoutProtocol('example.com?query=value')).toBe(false)
    })

    it('should reject host with fragment', () => {
      expect(validateHostWithoutProtocol('example.com#fragment')).toBe(false)
    })
  })

  describe('edge cases', () => {
    it('should handle trimmed whitespace', () => {
      expect(validateHostWithoutProtocol('  example.com  ')).toBe(true)
    })

    it('should reject protocol with whitespace', () => {
      expect(validateHostWithoutProtocol('  http://example.com  ')).toBe(false)
    })

    it('should accept valid host after trimming', () => {
      expect(validateHostWithoutProtocol('  subdomain.example.com  ')).toBe(true)
    })
  })
})
