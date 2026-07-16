import { getMostRecentPaymentMethodId } from '../getMostRecentPaymentMethodId'

describe('getMostRecentPaymentMethodId', () => {
  describe('GIVEN no payments', () => {
    it('WHEN payments is undefined THEN should return undefined', () => {
      expect(getMostRecentPaymentMethodId(undefined)).toBeUndefined()
    })

    it('WHEN payments is null THEN should return undefined', () => {
      expect(getMostRecentPaymentMethodId(null)).toBeUndefined()
    })

    it('WHEN payments is empty array THEN should return undefined', () => {
      expect(getMostRecentPaymentMethodId([])).toBeUndefined()
    })
  })

  describe('GIVEN payments without paymentMethodId', () => {
    it('THEN should return undefined', () => {
      const payments = [
        { createdAt: '2024-01-15T10:00:00Z', paymentMethodId: null },
        { createdAt: '2024-01-16T10:00:00Z', paymentMethodId: undefined },
      ]

      expect(getMostRecentPaymentMethodId(payments)).toBeUndefined()
    })
  })

  describe('GIVEN single payment with paymentMethodId', () => {
    it('THEN should return that paymentMethodId', () => {
      const payments = [{ createdAt: '2024-01-15T10:00:00Z', paymentMethodId: 'pm-123' }]

      expect(getMostRecentPaymentMethodId(payments)).toBe('pm-123')
    })
  })

  describe('GIVEN multiple payments with paymentMethodId', () => {
    it('THEN should return the paymentMethodId from the most recent payment', () => {
      const payments = [
        { createdAt: '2024-01-15T10:00:00Z', paymentMethodId: 'pm-oldest' },
        { createdAt: '2024-01-17T10:00:00Z', paymentMethodId: 'pm-newest' },
        { createdAt: '2024-01-16T10:00:00Z', paymentMethodId: 'pm-middle' },
      ]

      expect(getMostRecentPaymentMethodId(payments)).toBe('pm-newest')
    })
  })

  describe('GIVEN mixed payments with and without paymentMethodId', () => {
    it('THEN should return the paymentMethodId from the most recent payment that has one', () => {
      const payments = [
        { createdAt: '2024-01-15T10:00:00Z', paymentMethodId: 'pm-old' },
        { createdAt: '2024-01-18T10:00:00Z', paymentMethodId: null },
        { createdAt: '2024-01-17T10:00:00Z', paymentMethodId: 'pm-newest-with-method' },
        { createdAt: '2024-01-16T10:00:00Z', paymentMethodId: undefined },
      ]

      expect(getMostRecentPaymentMethodId(payments)).toBe('pm-newest-with-method')
    })
  })
})
