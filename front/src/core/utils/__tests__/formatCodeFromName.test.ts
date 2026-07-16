import { formatCodeFromName } from '../formatCodeFromName'

describe('formatCodeFromName', () => {
  it('should convert name to lowercase', () => {
    const result = formatCodeFromName('MyName')

    expect(result).toBe('myname')
  })

  it('should replace spaces with underscores', () => {
    const result = formatCodeFromName('my name')

    expect(result).toBe('my_name')
  })

  it('should handle multiple spaces', () => {
    const result = formatCodeFromName('my name with spaces')

    expect(result).toBe('my_name_with_spaces')
  })

  it('should handle uppercase with spaces', () => {
    const result = formatCodeFromName('My Custom Role')

    expect(result).toBe('my_custom_role')
  })

  it('should return empty string for empty input', () => {
    const result = formatCodeFromName('')

    expect(result).toBe('')
  })

  it('should handle string with no spaces', () => {
    const result = formatCodeFromName('admin')

    expect(result).toBe('admin')
  })

  it('should handle consecutive spaces', () => {
    const result = formatCodeFromName('my  double  spaces')

    expect(result).toBe('my__double__spaces')
  })
})
