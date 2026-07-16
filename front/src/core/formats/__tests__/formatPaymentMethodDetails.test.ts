import { formatPaymentMethodDetails } from '../formatPaymentMethodDetails'
import { maskValue } from '../maskValue'

describe('formatPaymentMethodDetails', () => {
  describe('WHEN formatting payment method details', () => {
    it('THEN returns correct format with all fields present', () => {
      const result = formatPaymentMethodDetails({
        type: 'card',
        brand: 'visa',
        last4: '4242',
      })

      expect(result).toBe(`Card - Visa ${maskValue('4242', { withSpace: true })}`)
    })

    it('THEN returns correct format with type and brand only', () => {
      const result = formatPaymentMethodDetails({
        type: 'card',
        brand: 'visa',
        last4: null,
      })

      expect(result).toBe('Card - Visa')
    })

    it('THEN returns correct format with type and last4 only', () => {
      const result = formatPaymentMethodDetails({
        type: 'card',
        brand: null,
        last4: '4242',
      })

      expect(result).toBe(`Card ${maskValue('4242', { withSpace: true })}`)
    })

    it('THEN returns correct format with brand and last4 only', () => {
      const result = formatPaymentMethodDetails({
        type: null,
        brand: 'visa',
        last4: '4242',
      })

      expect(result).toBe(`Visa ${maskValue('4242', { withSpace: true })}`)
    })

    it('THEN returns correct format with only type', () => {
      const result = formatPaymentMethodDetails({
        type: 'card',
        brand: null,
        last4: null,
      })

      expect(result).toBe('Card')
    })

    it('THEN returns correct format with only brand', () => {
      const result = formatPaymentMethodDetails({
        type: null,
        brand: 'visa',
        last4: null,
      })

      expect(result).toBe('Visa')
    })

    it('THEN returns correct format with only last4', () => {
      const result = formatPaymentMethodDetails({
        type: null,
        brand: null,
        last4: '4242',
      })

      expect(result).toBe(`${maskValue('4242', { withSpace: true })}`)
    })

    it('THEN normalizes brand with underscores to spaces and capitalizes', () => {
      const result = formatPaymentMethodDetails({
        type: 'card',
        brand: 'american_express',
        last4: '4242',
      })

      expect(result).toBe(`Card - American Express ${maskValue('4242', { withSpace: true })}`)
    })

    it('THEN normalizes type with underscores to spaces and capitalizes', () => {
      const result = formatPaymentMethodDetails({
        type: 'credit_card',
        brand: 'visa',
        last4: '4242',
      })

      expect(result).toBe(`Credit Card - Visa ${maskValue('4242', { withSpace: true })}`)
    })

    it('THEN handles empty details object', () => {
      const result = formatPaymentMethodDetails({})

      expect(result).toBe('')
    })

    it('THEN handles null details', () => {
      const result = formatPaymentMethodDetails(null)

      expect(result).toBe('')
    })

    it('THEN handles undefined details', () => {
      const result = formatPaymentMethodDetails(undefined)

      expect(result).toBe('')
    })

    it('THEN does not add dash when type is missing', () => {
      const result = formatPaymentMethodDetails({
        type: null,
        brand: 'visa',
        last4: '4242',
      })

      expect(result).toBe(`Visa ${maskValue('4242', { withSpace: true })}`)
      expect(result).not.toContain(' - ')
    })

    it('THEN does not add dash when brand is missing', () => {
      const result = formatPaymentMethodDetails({
        type: 'card',
        brand: null,
        last4: '4242',
      })

      expect(result).toBe(`Card ${maskValue('4242', { withSpace: true })}`)
      expect(result).not.toContain(' - ')
    })

    it('THEN capitalizes single word correctly', () => {
      const result = formatPaymentMethodDetails({
        type: 'CARD',
        brand: 'VISA',
        last4: null,
      })

      expect(result).toBe('Card - Visa')
    })

    it('THEN handles empty strings as null', () => {
      const result = formatPaymentMethodDetails({
        type: '',
        brand: '',
        last4: '',
      })

      expect(result).toBe('')
    })
  })
})
