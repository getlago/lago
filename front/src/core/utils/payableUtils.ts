import { Payable } from '~/core/types/payable'

/**
 * Type guard to check if a payable is an Invoice
 *
 * @param payable - The payable object to check
 * @returns True if the payable is an Invoice, false otherwise
 */
export const isInvoice = (
  payable: Payable,
): payable is Extract<Payable, { __typename?: 'Invoice' }> => {
  return payable.payableType === 'Invoice'
}

/**
 * Type guard to check if a payable is a PaymentRequest
 *
 * @param payable - The payable object to check
 * @returns True if the payable is a PaymentRequest, false otherwise
 */
export const isPaymentRequest = (
  payable: Payable,
): payable is Extract<Payable, { __typename?: 'PaymentRequest' }> => {
  return payable.payableType === 'PaymentRequest'
}
