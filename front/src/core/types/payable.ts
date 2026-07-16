import { PaymentForPaymentsListFragment } from '~/generated/graphql'

/**
 * Payable type extracted from PaymentForPaymentsListFragment
 *
 * Represents a union type that can be either an Invoice or a PaymentRequest.
 * This type is used for type guards to safely narrow down the payable type.
 */
export type Payable = PaymentForPaymentsListFragment['payable']
