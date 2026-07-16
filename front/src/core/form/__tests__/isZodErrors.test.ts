import { isZodErrors } from '../isZodErrors'

describe('isZodErrors', () => {
  it('should return true for valid Zod errors array', () => {
    const validZodErrors = [
      { message: 'Required', path: ['field1'] },
      { message: 'Invalid email', path: ['user', 'email'] },
      { message: 'Too short', path: ['password'] },
    ]

    expect(isZodErrors(validZodErrors)).toBe(true)
  })

  it('should return true for empty array', () => {
    expect(isZodErrors([])).toBe(true)
  })

  it('should return true for single error object in array', () => {
    const singleError = [{ message: 'Invalid value', path: ['field'] }]

    expect(isZodErrors(singleError)).toBe(true)
  })

  it('should return true for errors with nested paths', () => {
    const nestedPathErrors = [
      { message: 'Required', path: ['user', 'profile', 'name'] },
      { message: 'Invalid', path: ['settings', 0, 'value'] },
    ]

    expect(isZodErrors(nestedPathErrors)).toBe(true)
  })

  it('should return true for errors with empty paths', () => {
    const emptyPathErrors = [{ message: 'Root error', path: [] }]

    expect(isZodErrors(emptyPathErrors)).toBe(true)
  })

  it('should return false for null', () => {
    expect(isZodErrors(null)).toBe(false)
  })

  it('should return false for undefined', () => {
    expect(isZodErrors(undefined)).toBe(false)
  })

  it('should return false for non-array values', () => {
    expect(isZodErrors('string')).toBe(false)
    expect(isZodErrors(123)).toBe(false)
    expect(isZodErrors(true)).toBe(false)
    expect(isZodErrors({})).toBe(false)
  })

  it('should return false for array with invalid error objects - missing message', () => {
    const invalidErrors = [
      { path: ['field'] }, // missing message
    ]

    expect(isZodErrors(invalidErrors)).toBe(false)
  })

  it('should return false for array with invalid error objects - missing path', () => {
    const invalidErrors = [
      { message: 'Error message' }, // missing path
    ]

    expect(isZodErrors(invalidErrors)).toBe(false)
  })

  it('should return false for array with invalid error objects - non-string message', () => {
    const invalidErrors = [
      { message: 123, path: ['field'] }, // message is not string
    ]

    expect(isZodErrors(invalidErrors)).toBe(false)
  })

  it('should return false for array with invalid error objects - non-array path', () => {
    const invalidErrors = [
      { message: 'Error', path: 'field' }, // path is not array
    ]

    expect(isZodErrors(invalidErrors)).toBe(false)
  })

  it('should return false for array with null/undefined elements', () => {
    const invalidErrors = [null, { message: 'Valid error', path: ['field'] }]

    expect(isZodErrors(invalidErrors)).toBe(false)
  })

  it('should return false for array with primitive elements', () => {
    const invalidErrors = ['string error', { message: 'Valid error', path: ['field'] }]

    expect(isZodErrors(invalidErrors)).toBe(false)
  })

  it('should return false for mixed valid and invalid error objects', () => {
    const mixedErrors = [
      { message: 'Valid error', path: ['field1'] },
      { message: 123, path: ['field2'] }, // invalid message type
      { message: 'Another valid error', path: ['field3'] },
    ]

    expect(isZodErrors(mixedErrors)).toBe(false)
  })

  it('should return false for array with extra properties but missing required ones', () => {
    const invalidErrors = [
      {
        message: 'Error message',
        code: 'INVALID',
        // missing path property
      },
    ]

    expect(isZodErrors(invalidErrors)).toBe(false)
  })

  it('should return true for valid errors with extra properties', () => {
    const validErrorsWithExtra = [
      {
        message: 'Error message',
        path: ['field'],
        code: 'INVALID',
        expected: 'string',
        received: 'number',
      },
    ]

    expect(isZodErrors(validErrorsWithExtra)).toBe(true)
  })

  it('should handle complex path structures', () => {
    const complexPathErrors = [
      { message: 'Error', path: ['users', 0, 'profile', 'settings', 'theme'] },
      { message: 'Error', path: [42, 'nested', true, 'complex'] },
    ]

    expect(isZodErrors(complexPathErrors)).toBe(true)
  })
})
