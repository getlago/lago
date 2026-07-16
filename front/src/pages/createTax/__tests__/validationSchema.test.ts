import { emptyTaxDefaultValues, taxFormSchema } from '../validationSchema'

describe('taxFormSchema', () => {
  describe('GIVEN valid form values', () => {
    it.each([
      [{ name: 'Tax Name', code: 'TAX', rate: '10', description: '' }],
      [{ name: 'Tax Name', code: 'TAX', rate: '100', description: '' }],
      [{ name: 'Tax Name', code: 'TAX', rate: '0', description: '' }],
      [{ name: 'Tax Name', code: 'TAX', rate: '99.9999', description: 'Optional description' }],
      [{ name: 'Tax Name', code: 'TAX', rate: '10' }],
    ])('THEN validation passes for valid values', (values) => {
      const result = taxFormSchema.safeParse(values)

      expect(result.success).toBe(true)
    })
  })

  describe('GIVEN name is invalid', () => {
    describe('WHEN name is empty', () => {
      it('THEN validation fails', () => {
        const result = taxFormSchema.safeParse({ name: '', code: 'TAX', rate: '10' })

        expect(result.success).toBe(false)
      })
    })
  })

  describe('GIVEN code is invalid', () => {
    describe('WHEN code is empty', () => {
      it('THEN validation fails', () => {
        const result = taxFormSchema.safeParse({ name: 'Tax', code: '', rate: '10' })

        expect(result.success).toBe(false)
      })
    })
  })

  describe('GIVEN rate is invalid', () => {
    describe('WHEN rate is empty', () => {
      it('THEN validation fails', () => {
        const result = taxFormSchema.safeParse({ name: 'Tax', code: 'TAX', rate: '' })

        expect(result.success).toBe(false)
      })
    })

    describe('WHEN rate exceeds 100', () => {
      it('THEN validation fails', () => {
        const result = taxFormSchema.safeParse({ name: 'Tax', code: 'TAX', rate: '101' })

        expect(result.success).toBe(false)
      })
    })

    describe('WHEN rate is not a number', () => {
      it('THEN validation fails', () => {
        const result = taxFormSchema.safeParse({ name: 'Tax', code: 'TAX', rate: 'abc' })

        expect(result.success).toBe(false)
      })
    })
  })

  describe('emptyTaxDefaultValues', () => {
    it('THEN should have all fields empty', () => {
      expect(emptyTaxDefaultValues).toEqual({
        code: '',
        description: '',
        name: '',
        rate: '',
      })
    })
  })
})
