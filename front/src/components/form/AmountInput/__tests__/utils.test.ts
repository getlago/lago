import { getAmountInputError } from '../utils'

describe('getAmountInputError', () => {
  describe('WHEN silentError is true', () => {
    it('THEN returns undefined', () => {
      const touched = { fieldName: true }
      const errors = { fieldName: 'Error message' }

      const result = getAmountInputError(true, true, touched, errors, 'fieldName')

      expect(result).toBeUndefined()
    })
  })

  describe('WHEN silentError is false', () => {
    describe('AND displayErrorText is true', () => {
      it('THEN returns error message when field is touched and has error', () => {
        const touched = { fieldName: true }
        const errors = { fieldName: 'Error message' }

        const result = getAmountInputError(false, true, touched, errors, 'fieldName')

        expect(result).toBe('Error message')
      })

      it('THEN returns undefined when field is not touched', () => {
        const touched = { fieldName: false }
        const errors = { fieldName: 'Error message' }

        const result = getAmountInputError(false, true, touched, errors, 'fieldName')

        expect(result).toBeUndefined()
      })

      it('THEN returns undefined when field has no error', () => {
        const touched = { fieldName: true }
        const errors = {}

        const result = getAmountInputError(false, true, touched, errors, 'fieldName')

        expect(result).toBeUndefined()
      })

      it('THEN returns undefined when field is not touched and has no error', () => {
        const touched = {}
        const errors = {}

        const result = getAmountInputError(false, true, touched, errors, 'fieldName')

        expect(result).toBeUndefined()
      })
    })

    describe('AND displayErrorText is false', () => {
      it('THEN returns true when field has error', () => {
        const touched = { fieldName: true }
        const errors = { fieldName: 'Error message' }

        const result = getAmountInputError(false, false, touched, errors, 'fieldName')

        expect(result).toBe(true)
      })

      it('THEN returns false when field has no error', () => {
        const touched = { fieldName: true }
        const errors = {}

        const result = getAmountInputError(false, false, touched, errors, 'fieldName')

        expect(result).toBe(false)
      })

      it('THEN returns true when field is not touched but has error', () => {
        const touched = {}
        const errors = { fieldName: 'Error message' }

        const result = getAmountInputError(false, false, touched, errors, 'fieldName')

        expect(result).toBe(true)
      })
    })
  })

  describe('WHEN using nested field names', () => {
    it('THEN correctly accesses nested error values', () => {
      const touched = { parent: { child: true } }
      const errors = { parent: { child: 'Nested error' } }

      const result = getAmountInputError(false, true, touched, errors, 'parent.child')

      expect(result).toBe('Nested error')
    })

    it('THEN returns undefined for nested field when not touched', () => {
      const touched = { parent: { child: false } }
      const errors = { parent: { child: 'Nested error' } }

      const result = getAmountInputError(false, true, touched, errors, 'parent.child')

      expect(result).toBeUndefined()
    })
  })
})
