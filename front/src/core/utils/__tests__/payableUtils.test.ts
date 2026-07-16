import { Payable } from '~/core/types/payable'
import { isInvoice, isPaymentRequest } from '~/core/utils/payableUtils'

describe('payableUtils', () => {
  describe('isInvoice', () => {
    it('should return true when payable is an Invoice', () => {
      const payable: Payable = {
        __typename: 'Invoice',
        id: 'invoice-1',
        number: 'INV-001',
        payableType: 'Invoice',
      }

      expect(isInvoice(payable)).toBe(true)
    })

    it('should return false when payable is a PaymentRequest', () => {
      const payable: Payable = {
        __typename: 'PaymentRequest',
        payableType: 'PaymentRequest',
        invoices: [],
      }

      expect(isInvoice(payable)).toBe(false)
    })
  })

  describe('isPaymentRequest', () => {
    it('should return true when payable is a PaymentRequest', () => {
      const payable: Payable = {
        __typename: 'PaymentRequest',
        payableType: 'PaymentRequest',
        invoices: [{ __typename: 'Invoice', id: 'invoice-1', number: 'INV-001' }],
      }

      expect(isPaymentRequest(payable)).toBe(true)
    })

    it('should return false when payable is an Invoice', () => {
      const payable: Payable = {
        __typename: 'Invoice',
        id: 'invoice-1',
        number: 'INV-001',
        payableType: 'Invoice',
      }

      expect(isPaymentRequest(payable)).toBe(false)
    })
  })
})
