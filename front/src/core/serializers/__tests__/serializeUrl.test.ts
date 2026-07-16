import { serializeUrl } from '~/core/serializers/serializeUrl'

describe('serializeUrl()', () => {
  describe('GIVEN a valid URL', () => {
    it.each([
      ['simple https URL', 'https://example.com', 'https://example.com/'],
      ['simple http URL', 'http://example.com', 'http://example.com/'],
      ['URL with path', 'https://example.com/path/to/page', 'https://example.com/path/to/page'],
      ['URL with query params', 'https://example.com?foo=bar', 'https://example.com/?foo=bar'],
      ['URL with fragment', 'https://example.com#section', 'https://example.com/#section'],
      ['URL with port', 'https://example.com:8080', 'https://example.com:8080/'],
      [
        'URL with path, query, and fragment',
        'https://example.com/path?key=value#hash',
        'https://example.com/path?key=value#hash',
      ],
    ])('THEN should return the normalized href for %s', (_, input, expected) => {
      expect(serializeUrl(input)).toBe(expected)
    })
  })

  describe('GIVEN an invalid URL', () => {
    it.each([
      ['empty string', ''],
      ['plain text', 'not-a-url'],
      ['missing protocol', 'example.com'],
      ['only protocol', 'https://'],
      ['relative path', '/path/to/page'],
      ['spaces', 'https://exam ple.com'],
    ])('THEN should return null for %s', (_, input) => {
      expect(serializeUrl(input)).toBeNull()
    })
  })
})
