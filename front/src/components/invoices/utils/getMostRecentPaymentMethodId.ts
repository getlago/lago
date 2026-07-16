type PaymentWithMethodId = {
  createdAt: string
  paymentMethodId?: string | null
}

/**
 * Gets the payment method ID from the most recent payment that has a paymentMethodId.
 * Payments are sorted by createdAt in descending order (most recent first).
 *
 * @param payments - Array of payments with createdAt and optional paymentMethodId
 * @returns The paymentMethodId of the most recent payment that has one, or undefined if none found
 */
export const getMostRecentPaymentMethodId = (
  payments: PaymentWithMethodId[] | null | undefined,
): string | undefined => {
  if (!payments?.length) {
    return undefined
  }

  const paymentWithMethodId = [...payments]
    .filter((payment) => !!payment.paymentMethodId)
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())[0]

  return paymentWithMethodId?.paymentMethodId ?? undefined
}
