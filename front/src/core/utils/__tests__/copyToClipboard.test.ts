import { addToast } from '~/core/apolloClient'
import { copyToClipboard } from '~/core/utils/copyToClipboard'

// Mock addToast function
jest.mock('~/core/apolloClient', () => ({
  addToast: jest.fn(),
}))

Object.assign(window.navigator, {
  clipboard: {
    writeText: jest.fn().mockImplementation(() => Promise.resolve()),
  },
})

describe('copyToClipboard', () => {
  it('should copy to clipboard', () => {
    copyToClipboard('the text that needs to be copied')

    expect(window.navigator.clipboard.writeText).toHaveBeenCalledWith(
      'the text that needs to be copied',
    )
  })

  it('should filter out comments', () => {
    const value = `# comment
    the text that needs to be copied`

    copyToClipboard(value, { ignoreComment: true })
    expect(window.navigator.clipboard.writeText).toHaveBeenCalledWith(
      'the text that needs to be copied',
    )
  })

  it('should be able to copy when navigator.clipboard is not available', () => {
    // Mock navigator.clipboard to throw error
    const originalClipboard = { ...navigator.clipboard }

    Object.assign(navigator.clipboard, {
      writeText: jest.fn().mockImplementation(() => {
        throw new Error('Clipboard not available')
      }),
    })

    document.execCommand = jest.fn().mockImplementation(() => true)

    const textArea = document.createElement('textarea')
    const mockCreateElement = jest.spyOn(document, 'createElement').mockReturnValue(textArea)

    copyToClipboard('fallback text')

    expect(document.execCommand).toHaveBeenCalledWith('copy')
    expect(textArea.value).toBe('fallback text')

    // Restore mocks
    Object.assign(navigator.clipboard, originalClipboard)
    mockCreateElement.mockRestore()
  })

  it('should show error toast when all clipboard methods fail', () => {
    // Mock navigator.clipboard to throw error
    const originalClipboard = { ...navigator.clipboard }

    Object.assign(navigator.clipboard, {
      writeText: jest.fn().mockImplementation(() => {
        throw new Error('Clipboard not available')
      }),
    })

    // Mock document.execCommand to also fail
    document.execCommand = jest.fn().mockImplementation(() => {
      throw new Error('execCommand failed')
    })

    // Should throw error but catch it internally
    expect(() => {
      copyToClipboard('failing text')
    }).toThrow('Unable to copy to clipboard')

    // Verify error toast was called
    expect(addToast).toHaveBeenCalledWith({
      severity: 'danger',
      translateKey: 'text_1745919770448pvibiukolis',
    })

    // Restore mocks
    Object.assign(navigator.clipboard, originalClipboard)
    jest.restoreAllMocks()
  })

  it('should filter out comments when using fallback clipboard method', () => {
    // Mock navigator.clipboard to throw error
    const originalClipboard = { ...navigator.clipboard }

    Object.assign(navigator.clipboard, {
      writeText: jest.fn().mockImplementation(() => {
        throw new Error('Clipboard not available')
      }),
    })

    // Mock document.execCommand
    document.execCommand = jest.fn().mockImplementation(() => true)

    // Create a real textarea to use for the test
    const textArea = document.createElement('textarea')
    const mockCreateElement = jest.spyOn(document, 'createElement').mockReturnValue(textArea)

    const value = `# comment
    the text that needs to be copied`

    copyToClipboard(value, { ignoreComment: true })

    // Verify the filtered text was used
    expect(textArea.value).toBe('the text that needs to be copied')
    expect(document.execCommand).toHaveBeenCalledWith('copy')

    // Restore mocks
    Object.assign(navigator.clipboard, originalClipboard)
    mockCreateElement.mockRestore()
    jest.restoreAllMocks()
  })
})
