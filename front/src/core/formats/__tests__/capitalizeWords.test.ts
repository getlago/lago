import { capitalizeWords } from '../capitalizeWords'

describe('capitalizeWords', () => {
  it('should capitalize the first letter of each word', () => {
    expect(capitalizeWords('hello world')).toBe('Hello World')
    expect(capitalizeWords('foo bar baz')).toBe('Foo Bar Baz')
  })

  it('should convert the rest of each word to lowercase', () => {
    expect(capitalizeWords('HELLO WORLD')).toBe('Hello World')
    expect(capitalizeWords('hELLo WoRLd')).toBe('Hello World')
  })

  it('should handle empty string', () => {
    expect(capitalizeWords('')).toBe('')
  })
})
