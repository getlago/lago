import { CreditNoteReasonEnum, CurrencyEnum } from '~/generated/graphql'

export type FromFee = {
  id: string
  checked: boolean
  maxAmount: number
  name: string
  value: string | number
  isTrueUpFee?: boolean
  isReadOnly?: boolean
  succeededAt?: string
  appliedTaxes?: {
    id: string
    taxName: string
    taxRate: number
  }[]
}

export interface FeesPerInvoice {
  [subcriptionId: string]: {
    subscriptionName: string
    fees: FromFee[]
  }
}

export enum CreditTypeEnum {
  credit = 'credit',
  refund = 'refund',
  offset = 'offset',
}

export interface CreditNoteForm {
  reason: CreditNoteReasonEnum
  creditAmount: number
  amountCurrency: CurrencyEnum
  refundAmount: number
  payBack: { type?: CreditTypeEnum; value?: number }[]
  description?: string
  fees?: FeesPerInvoice
  addOnFee?: FromFee[]
  creditFee?: FromFee[]
  metadata: Array<{
    key: string
    value: string
  }>
}

export enum CreditNoteFeeErrorEnum {
  minZero = 'minZero',
  overMax = 'overMax',
}

export enum PayBackErrorEnum {
  maxRefund = 'maxRefund',
  maxCredit = 'maxCredit',
  maxOffset = 'maxOffset',
  maxTotalInvoice = 'maxTotalInvoice',
}
