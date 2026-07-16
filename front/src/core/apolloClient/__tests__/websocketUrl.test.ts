import { buildWebSocketUrl } from '~/core/apolloClient/websocketUrl'

describe('buildWebSocketUrl', () => {
  describe('HTTPS URLs', () => {
    it('should convert HTTPS to WSS', () => {
      const result = buildWebSocketUrl('https://api.example.com')

      expect(result.websocketUrl).toBe('wss://api.example.com')
      expect(result.cableUrl).toBe('wss://api.example.com/cable')
    })

    it('should handle HTTPS URL with trailing slash', () => {
      const result = buildWebSocketUrl('https://api.example.com/')

      expect(result.websocketUrl).toBe('wss://api.example.com')
      expect(result.cableUrl).toBe('wss://api.example.com/cable')
    })

    it('should handle HTTPS URL with path and trailing slash', () => {
      const result = buildWebSocketUrl('https://api.example.com/api/v1/')

      expect(result.websocketUrl).toBe('wss://api.example.com/api/v1')
      expect(result.cableUrl).toBe('wss://api.example.com/api/v1/cable')
    })

    it('should handle HTTPS URL with port', () => {
      const result = buildWebSocketUrl('https://api.example.com:8080')

      expect(result.websocketUrl).toBe('wss://api.example.com:8080')
      expect(result.cableUrl).toBe('wss://api.example.com:8080/cable')
    })

    it('should handle HTTPS URL with port and trailing slash', () => {
      const result = buildWebSocketUrl('https://api.example.com:8080/')

      expect(result.websocketUrl).toBe('wss://api.example.com:8080')
      expect(result.cableUrl).toBe('wss://api.example.com:8080/cable')
    })
  })

  describe('HTTP URLs', () => {
    it('should convert HTTP to WS', () => {
      const result = buildWebSocketUrl('http://localhost:3000')

      expect(result.websocketUrl).toBe('ws://localhost:3000')
      expect(result.cableUrl).toBe('ws://localhost:3000/cable')
    })

    it('should handle HTTP URL with trailing slash', () => {
      const result = buildWebSocketUrl('http://localhost:3000/')

      expect(result.websocketUrl).toBe('ws://localhost:3000')
      expect(result.cableUrl).toBe('ws://localhost:3000/cable')
    })

    it('should handle HTTP URL with path', () => {
      const result = buildWebSocketUrl('http://localhost:3000/api')

      expect(result.websocketUrl).toBe('ws://localhost:3000/api')
      expect(result.cableUrl).toBe('ws://localhost:3000/api/cable')
    })

    it('should handle HTTP URL with path and trailing slash', () => {
      const result = buildWebSocketUrl('http://localhost:3000/api/')

      expect(result.websocketUrl).toBe('ws://localhost:3000/api')
      expect(result.cableUrl).toBe('ws://localhost:3000/api/cable')
    })
  })

  describe('Edge cases', () => {
    it('should handle URL with query parameters', () => {
      const result = buildWebSocketUrl('https://api.example.com?version=1')

      expect(result.websocketUrl).toBe('wss://api.example.com?version=1')
      expect(result.cableUrl).toBe('wss://api.example.com/cable?version=1')
    })

    it('should handle URL with hash', () => {
      const result = buildWebSocketUrl('https://api.example.com#section')

      expect(result.websocketUrl).toBe('wss://api.example.com#section')
      expect(result.cableUrl).toBe('wss://api.example.com/cable#section')
    })

    it('should handle URL with both query parameters and hash', () => {
      const result = buildWebSocketUrl('https://api.example.com?version=1#section')

      expect(result.websocketUrl).toBe('wss://api.example.com?version=1#section')
      expect(result.cableUrl).toBe('wss://api.example.com/cable?version=1#section')
    })

    it('should handle URL with subdomain', () => {
      const result = buildWebSocketUrl('https://staging.api.example.com')

      expect(result.websocketUrl).toBe('wss://staging.api.example.com')
      expect(result.cableUrl).toBe('wss://staging.api.example.com/cable')
    })

    it('should handle URL with multiple path segments', () => {
      const result = buildWebSocketUrl('https://api.example.com/v1/graphql/')

      expect(result.websocketUrl).toBe('wss://api.example.com/v1/graphql')
      expect(result.cableUrl).toBe('wss://api.example.com/v1/graphql/cable')
    })
  })

  describe('Error cases', () => {
    it('should throw error for invalid URL', () => {
      expect(() => buildWebSocketUrl('not-a-url')).toThrow()
    })

    it('should throw error for empty string', () => {
      expect(() => buildWebSocketUrl('')).toThrow()
    })

    it('should throw error for URL without protocol', () => {
      expect(() => buildWebSocketUrl('api.example.com')).toThrow()
    })
  })

  describe('Real-world scenarios', () => {
    it('should handle production API URL', () => {
      const result = buildWebSocketUrl('https://api.lago.dev')

      expect(result.websocketUrl).toBe('wss://api.lago.dev')
      expect(result.cableUrl).toBe('wss://api.lago.dev/cable')
    })

    it('should handle staging API URL', () => {
      const result = buildWebSocketUrl('https://staging-api.lago.dev')

      expect(result.websocketUrl).toBe('wss://staging-api.lago.dev')
      expect(result.cableUrl).toBe('wss://staging-api.lago.dev/cable')
    })

    it('should handle local development URL', () => {
      const result = buildWebSocketUrl('http://localhost:3000')

      expect(result.websocketUrl).toBe('ws://localhost:3000')
      expect(result.cableUrl).toBe('ws://localhost:3000/cable')
    })

    it('should handle local development URL with path', () => {
      const result = buildWebSocketUrl('http://localhost:3000/api')

      expect(result.websocketUrl).toBe('ws://localhost:3000/api')
      expect(result.cableUrl).toBe('ws://localhost:3000/api/cable')
    })
  })
})
