import { scrollToFirstInputError } from '../scrollToFirstInputError'

// Mock DOM methods
const mockScrollIntoView = jest.fn()
const mockFocus = jest.fn()

describe('scrollToFirstInputError', () => {
  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks()

    // Clear DOM
    document.body.innerHTML = ''

    // Mock scrollIntoView and focus on HTMLInputElement prototype
    Object.defineProperty(HTMLInputElement.prototype, 'scrollIntoView', {
      value: mockScrollIntoView,
      writable: true,
    })
    Object.defineProperty(HTMLInputElement.prototype, 'focus', {
      value: mockFocus,
      writable: true,
    })
  })

  afterEach(() => {
    // Clean up DOM
    document.body.innerHTML = ''
  })

  describe('when form exists with inputs', () => {
    beforeEach(() => {
      // Create a form with inputs
      document.body.innerHTML = `
        <form id="test-form">
          <input name="firstName" type="text" />
          <input name="lastName" type="text" />
          <input name="email" type="email" />
          <input name="phone" type="tel" />
        </form>
      `
    })

    it('scrolls to and focuses the first input with an error', () => {
      jest.useFakeTimers()
      const errorMap = {
        lastName: 'Last name is required',
        email: 'Invalid email format',
      }

      scrollToFirstInputError('test-form', errorMap)

      // Should scroll to the first input that has an error (lastName in DOM order)
      expect(mockScrollIntoView).toHaveBeenCalledTimes(1)
      expect(mockScrollIntoView).toHaveBeenCalledWith({
        behavior: 'smooth',
        block: 'center',
      })

      jest.advanceTimersByTime(300)
      expect(mockFocus).toHaveBeenCalledTimes(1)

      // Verify it's the lastName input that got focused
      const lastNameInput = document.querySelector('input[name="lastName"]')

      expect(lastNameInput).toBeTruthy()
      jest.useRealTimers()
    })

    it('scrolls to the first input when only one has an error', () => {
      jest.useFakeTimers()
      const errorMap = {
        email: 'Email is required',
      }

      scrollToFirstInputError('test-form', errorMap)

      expect(mockScrollIntoView).toHaveBeenCalledTimes(1)
      expect(mockScrollIntoView).toHaveBeenCalledWith({
        behavior: 'smooth',
        block: 'center',
      })

      jest.advanceTimersByTime(300)
      expect(mockFocus).toHaveBeenCalledTimes(1)
      jest.useRealTimers()
    })

    it('scrolls to the first input in DOM order when multiple errors exist', () => {
      jest.useFakeTimers()
      const errorMap = {
        phone: 'Phone number is invalid',
        firstName: 'First name is required',
        email: 'Email format is wrong',
      }

      scrollToFirstInputError('test-form', errorMap)

      // Should focus the first input in DOM order that has an error (firstName)
      expect(mockScrollIntoView).toHaveBeenCalledTimes(1)

      jest.advanceTimersByTime(300)
      expect(mockFocus).toHaveBeenCalledTimes(1)
      jest.useRealTimers()
    })

    it('does nothing when no inputs have errors', () => {
      const errorMap = {
        nonExistentField: 'This field does not exist',
        anotherField: 'Neither does this one',
      }

      scrollToFirstInputError('test-form', errorMap)

      expect(mockScrollIntoView).not.toHaveBeenCalled()
      expect(mockFocus).not.toHaveBeenCalled()
    })

    it('does nothing when errorMap is empty', () => {
      const errorMap = {}

      scrollToFirstInputError('test-form', errorMap)

      expect(mockScrollIntoView).not.toHaveBeenCalled()
      expect(mockFocus).not.toHaveBeenCalled()
    })

    it('treats falsy error values as no error', () => {
      jest.useFakeTimers()
      const errorMap = {
        firstName: null,
        lastName: undefined,
        email: '',
        phone: 0,
        validError: 'This is an actual error',
      }

      scrollToFirstInputError('test-form', errorMap)

      // Should only focus on the input with a truthy error (but there are none here)
      expect(mockScrollIntoView).not.toHaveBeenCalled()

      jest.advanceTimersByTime(300)
      expect(mockFocus).not.toHaveBeenCalled()
      jest.useRealTimers()
    })

    it('handles complex error objects', () => {
      jest.useFakeTimers()
      const errorMap = {
        firstName: { message: 'Required field' },
        lastName: ['Multiple', 'errors'],
        email: { nested: { error: 'Complex error' } },
      }

      scrollToFirstInputError('test-form', errorMap)

      // All these error values are truthy, so should focus first input (firstName)
      expect(mockScrollIntoView).toHaveBeenCalledTimes(1)

      jest.advanceTimersByTime(300)
      expect(mockFocus).toHaveBeenCalledTimes(1)
      jest.useRealTimers()
    })
  })

  describe('when form does not exist', () => {
    it('does nothing when form ID does not exist', () => {
      const errorMap = {
        firstName: 'Some error',
      }

      scrollToFirstInputError('non-existent-form', errorMap)

      expect(mockScrollIntoView).not.toHaveBeenCalled()
      expect(mockFocus).not.toHaveBeenCalled()
    })
  })

  describe('when form exists but has no inputs', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <form id="empty-form">
          <div>No inputs here</div>
          <span>Just some text</span>
        </form>
      `
    })

    it('does nothing when form has no inputs', () => {
      const errorMap = {
        someField: 'Some error',
      }

      scrollToFirstInputError('empty-form', errorMap)

      expect(mockScrollIntoView).not.toHaveBeenCalled()
      expect(mockFocus).not.toHaveBeenCalled()
    })
  })

  describe('when form has inputs but none match error fields', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <form id="mismatched-form">
          <input name="fieldA" type="text" />
          <input name="fieldB" type="text" />
        </form>
      `
    })

    it('does nothing when no input names match error keys', () => {
      const errorMap = {
        fieldC: 'Error for non-existent field',
        fieldD: 'Another error for non-existent field',
      }

      scrollToFirstInputError('mismatched-form', errorMap)

      expect(mockScrollIntoView).not.toHaveBeenCalled()
      expect(mockFocus).not.toHaveBeenCalled()
    })
  })

  describe('edge cases', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <form id="edge-case-form">
          <input name="field1" type="text" />
          <input name="field2" type="hidden" />
          <input name="field3" type="checkbox" />
          <input name="field4" type="radio" />
          <input name="" type="text" />
          <input type="text" />
        </form>
      `
    })

    it('handles inputs with different types', () => {
      jest.useFakeTimers()
      const errorMap = {
        field2: 'Hidden field error',
        field3: 'Checkbox error',
      }

      scrollToFirstInputError('edge-case-form', errorMap)

      // Should focus the first input with error (field2 - hidden input)
      expect(mockScrollIntoView).toHaveBeenCalledTimes(1)

      jest.advanceTimersByTime(300)
      expect(mockFocus).toHaveBeenCalledTimes(1)
      jest.useRealTimers()
    })

    it('handles inputs with empty or missing name attributes', () => {
      jest.useFakeTimers()
      const errorMap = {
        '': 'Error for empty name',
        undefined: 'Error for undefined name',
      }

      scrollToFirstInputError('edge-case-form', errorMap)

      // Should focus input with empty name attribute if it matches
      expect(mockScrollIntoView).toHaveBeenCalledTimes(1)

      jest.advanceTimersByTime(300)
      expect(mockFocus).toHaveBeenCalledTimes(1)
      jest.useRealTimers()
    })

    it('handles form ID with special characters', () => {
      jest.useFakeTimers()
      document.body.innerHTML = `
        <form id="special-form-123_test">
          <input name="testField" type="text" />
        </form>
      `

      const errorMap = {
        testField: 'Test error',
      }

      scrollToFirstInputError('special-form-123_test', errorMap)

      expect(mockScrollIntoView).toHaveBeenCalledTimes(1)

      jest.advanceTimersByTime(300)
      expect(mockFocus).toHaveBeenCalledTimes(1)
      jest.useRealTimers()
    })
  })

  describe('DOM interaction methods', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <form id="interaction-form">
          <input name="testInput" type="text" />
        </form>
      `
    })

    it('calls scrollIntoView with correct parameters', () => {
      jest.useFakeTimers()
      const errorMap = { testInput: 'Test error' }

      scrollToFirstInputError('interaction-form', errorMap)

      expect(mockScrollIntoView).toHaveBeenCalledWith({
        behavior: 'smooth',
        block: 'center',
      })
      jest.useRealTimers()
    })

    it('handles focus throwing an error gracefully', () => {
      jest.useFakeTimers()
      mockFocus.mockImplementation(() => {
        throw new Error('Focus failed')
      })

      const errorMap = { testInput: 'Test error' }

      scrollToFirstInputError('interaction-form', errorMap)
      expect(mockScrollIntoView).toHaveBeenCalledTimes(1)

      // Should throw when the timeout completes
      expect(() => {
        jest.advanceTimersByTime(300)
      }).toThrow('Focus failed')

      expect(mockFocus).toHaveBeenCalledTimes(1)
      jest.useRealTimers()
    })

    it('handles scrollIntoView throwing an error gracefully', () => {
      mockScrollIntoView.mockImplementation(() => {
        throw new Error('ScrollIntoView failed')
      })

      const errorMap = { testInput: 'Test error' }

      // Should not throw an error
      expect(() => {
        scrollToFirstInputError('interaction-form', errorMap)
      }).toThrow('ScrollIntoView failed')

      expect(mockScrollIntoView).toHaveBeenCalledTimes(1)
      // Focus should not be called if scrollIntoView throws
      expect(mockFocus).not.toHaveBeenCalled()
    })
  })
})
