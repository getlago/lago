import { isInvoicePartiallyPaid } from '~/core/constants/statusInvoiceMapping'

describe('isInvoicePartiallyPaid', () => {
  describe('GIVEN both amounts are positive', () => {
    it('THEN should return true', () => {
      expect(isInvoicePartiallyPaid(5000, 5000)).toBe(true)
    })

    it('WHEN amounts are strings THEN should return true', () => {
      expect(isInvoicePartiallyPaid('5000', '5000')).toBe(true)
    })
  })

  describe('GIVEN totalPaidAmountCents is 0', () => {
    it('THEN should return false', () => {
      expect(isInvoicePartiallyPaid(0, 5000)).toBe(false)
    })

    it('WHEN amount is string "0" THEN should return false', () => {
      expect(isInvoicePartiallyPaid('0', '5000')).toBe(false)
    })
  })

  describe('GIVEN totalDueAmountCents is 0', () => {
    it('THEN should return false', () => {
      expect(isInvoicePartiallyPaid(5000, 0)).toBe(false)
    })

    it('WHEN amount is string "0" THEN should return false', () => {
      expect(isInvoicePartiallyPaid('5000', '0')).toBe(false)
    })
  })

  describe('GIVEN both amounts are 0', () => {
    it('THEN should return false', () => {
      expect(isInvoicePartiallyPaid(0, 0)).toBe(false)
    })
  })

  describe('GIVEN undefined values', () => {
    it('WHEN both are undefined THEN should return false', () => {
      expect(isInvoicePartiallyPaid(undefined, undefined)).toBe(false)
    })

    it('WHEN totalPaidAmountCents is undefined THEN should return false', () => {
      expect(isInvoicePartiallyPaid(undefined, 5000)).toBe(false)
    })

    it('WHEN totalDueAmountCents is undefined THEN should return false', () => {
      expect(isInvoicePartiallyPaid(5000, undefined)).toBe(false)
    })
  })

  describe('GIVEN negative values', () => {
    it('WHEN totalPaidAmountCents is negative THEN should return false', () => {
      expect(isInvoicePartiallyPaid(-100, 5000)).toBe(false)
    })

    it('WHEN totalDueAmountCents is negative THEN should return false', () => {
      expect(isInvoicePartiallyPaid(5000, -100)).toBe(false)
    })
  })
})
