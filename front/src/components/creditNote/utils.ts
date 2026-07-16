import { deserializeAmount, serializeAmount } from '~/core/serializers/serializeAmount'
import {
  CreditNoteItemInput,
  CreditNoteTableItemFragment,
  CurrencyEnum,
  Invoice,
  InvoiceForCreditNoteFormCalculationFragment,
  InvoiceTypeEnum,
} from '~/generated/graphql'

import { CreditNoteForm, CreditTypeEnum, FeesPerInvoice, FromFee } from './types'

// ----------------------------------------
// PayBack Fields Helper
// ----------------------------------------

interface PayBackFieldInfo {
  path: string
  value: number
  show: boolean
}

export interface PayBackFields {
  credit: PayBackFieldInfo
  refund: PayBackFieldInfo
  offset: PayBackFieldInfo
}

type PayBackItem = { type?: CreditTypeEnum | string; value?: number }

/**
 * Helper to get payBack field info by type.
 * Visibility (`show`) is derived from presence in the array - if an item exists, it should be shown.
 * This avoids passing visibility flags around since the array structure already encodes visibility.
 */
export const getPayBackFields = (payBack: PayBackItem[] | undefined): PayBackFields => {
  const items = payBack || []

  const creditIndex = items.findIndex((p) => p?.type === CreditTypeEnum.credit)
  const refundIndex = items.findIndex((p) => p?.type === CreditTypeEnum.refund)
  const offsetIndex = items.findIndex((p) => p?.type === CreditTypeEnum.offset)

  return {
    credit: {
      path: creditIndex >= 0 ? `payBack.${creditIndex}.value` : '',
      value: creditIndex >= 0 ? Number(items[creditIndex]?.value || 0) : 0,
      show: creditIndex >= 0,
    },
    refund: {
      path: refundIndex >= 0 ? `payBack.${refundIndex}.value` : '',
      value: refundIndex >= 0 ? Number(items[refundIndex]?.value || 0) : 0,
      show: refundIndex >= 0,
    },
    offset: {
      path: offsetIndex >= 0 ? `payBack.${offsetIndex}.value` : '',
      value: offsetIndex >= 0 ? Number(items[offsetIndex]?.value || 0) : 0,
      show: offsetIndex >= 0,
    },
  }
}

export type CreditNoteFormCalculationCalculationProps = {
  currency: CurrencyEnum
  fees: FeesPerInvoice | undefined
  addonFees: FromFee[] | undefined
  hasError: boolean
}

// This method calculate the credit notes amounts to display
// It does parse once all items. If no coupon applied, values are used for display
// If coupon applied, it will calculate the credit note tax amount based on the coupon value on pro rata of each item
export const creditNoteFormCalculationCalculation = ({
  currency,
  fees,
  addonFees,
  hasError,
}: CreditNoteFormCalculationCalculationProps): {
  feeForEstimate: CreditNoteItemInput[] | undefined
} => {
  if (hasError) return { feeForEstimate: undefined }

  let feeForEstimate: CreditNoteItemInput[] | undefined = undefined

  if (!!Object.keys(fees || {}).length) {
    feeForEstimate = Object.keys(fees || {}).reduce<CreditNoteItemInput[]>((accSub, subKey) => {
      const subChild = ((fees as FeesPerInvoice) || {})[subKey]
      const subValues = subChild?.fees?.reduce<CreditNoteItemInput[]>((accFees, fee) => {
        if (fee.checked) {
          accFees.push({
            feeId: fee.id,
            amountCents: serializeAmount(fee.value, currency),
          })
        }
        return accFees
      }, [])

      return [...accSub, ...(subValues || [])]
    }, [])
  } else if (addonFees) {
    feeForEstimate = addonFees.reduce<CreditNoteItemInput[]>((acc, fee) => {
      if (!!fee.checked) {
        acc.push({
          feeId: fee.id,
          amountCents: serializeAmount(fee.value, currency),
        })
      }

      return acc
    }, [])
  }

  return {
    feeForEstimate,
  }
}

export enum CreditNoteType {
  VOIDED,
  ON_INVOICE,
  CREDIT,
  REFUND,
}

export const getCreditNoteTypes = ({
  creditAmountCents,
  refundAmountCents,
  offsetAmountCents,
}: Pick<
  CreditNoteTableItemFragment,
  'creditAmountCents' | 'refundAmountCents' | 'offsetAmountCents'
>): CreditNoteType[] => {
  const types: CreditNoteType[] = []

  if (Number(creditAmountCents) > 0) {
    types.push(CreditNoteType.CREDIT)
  }
  if (Number(offsetAmountCents) > 0) {
    types.push(CreditNoteType.ON_INVOICE)
  }
  if (Number(refundAmountCents) > 0) {
    types.push(CreditNoteType.REFUND)
  }

  return types
}

export const CREDIT_NOTE_TYPE_TRANSLATIONS_MAP: Record<CreditNoteType | 'MULTIPLE_TYPES', string> =
  {
    [CreditNoteType.VOIDED]: 'text_1727079454388ekfkh3vna8m',
    [CreditNoteType.ON_INVOICE]: 'text_1736431648426rjb1s8vq61n',
    [CreditNoteType.CREDIT]: 'text_1727079454388x9q4uz6ah71',
    [CreditNoteType.REFUND]: 'text_17270794543889mcmuhfq70p',
    MULTIPLE_TYPES: 'text_1736431648426vz8s9kj2f4p',
  }

/**
 * Formats a list of types into a human-readable string.
 * - 2 items: "Credit & refund"
 * - 3+ items: "Credit, on invoice & refund"
 * Only first word is capitalized, rest are lowercase.
 */
export const formatCreditNoteTypesForDisplay = (translatedTypes: string[]): string => {
  if (translatedTypes.length === 0) return ''
  if (translatedTypes.length === 1) return translatedTypes[0]

  const types = translatedTypes.map((t) => t.toLowerCase())
  const firstType = types[0].charAt(0).toUpperCase() + types[0].slice(1)
  const lastType = types[types.length - 1]
  const middleTypes = types.slice(1, -1)

  if (middleTypes.length === 0) {
    return `${firstType} & ${lastType}`
  }

  return `${firstType}, ${middleTypes.join(', ')} & ${lastType}`
}

const TRANSLATIONS_MAP_ISSUE_CREDIT_NOTE_DISABLED = {
  terminatedWallet: 'text_172908299496461z9ejmm2j7',
  fullyCovered: 'text_1729082994964zccpjmtotdy',
}

// ----------------------------------------
// Invoice Amount Helpers
// ----------------------------------------

type InvoiceAmountFields = Partial<
  Pick<Invoice, 'creditableAmountCents' | 'refundableAmountCents' | 'offsettableAmountCents'>
> | null

/**
 * Checks if the invoice has a creditable amount (creditableAmountCents > 0).
 * This represents the amount that can be credited back to the customer's account.
 */
export const hasCreditableAmount = (invoice?: InvoiceAmountFields): boolean => {
  return Number(invoice?.creditableAmountCents) > 0
}

/**
 * Checks if the invoice has a refundable amount (refundableAmountCents > 0).
 * This represents the amount that can be refunded as actual money.
 */
export const hasRefundableAmount = (invoice?: InvoiceAmountFields): boolean => {
  return Number(invoice?.refundableAmountCents) > 0
}

/**
 * Checks if the invoice has an offsettable amount (offsettableAmountCents > 0).
 * This represents the amount that can be offset against the source invoice.
 */
export const hasOffsettableAmount = (invoice?: InvoiceAmountFields): boolean => {
  return Number(invoice?.offsettableAmountCents) > 0
}

/**
 * Checks if the invoice has either a creditable or refundable amount.
 * When true, the credit note form allows editing amounts.
 * When false, the form uses offsettableAmountCents in read-only mode.
 */
export const hasCreditableOrRefundableAmount = (invoice?: InvoiceAmountFields): boolean => {
  return hasCreditableAmount(invoice) || hasRefundableAmount(invoice)
}

/**
 * Checks if credit note creation is possible for this invoice.
 * Returns true if any of the three amount types is available.
 */
export const canCreateCreditNote = (invoice?: InvoiceAmountFields): boolean => {
  return (
    hasCreditableAmount(invoice) || hasRefundableAmount(invoice) || hasOffsettableAmount(invoice)
  )
}

// ----------------------------------------
// Credit Note Creation Validation
// ----------------------------------------

export const isCreditNoteCreationDisabled = (
  invoice?: Partial<
    Pick<Invoice, 'creditableAmountCents' | 'refundableAmountCents' | 'offsettableAmountCents'>
  > | null,
) => {
  if (!invoice) return false

  return !canCreateCreditNote(invoice)
}

// ----------------------------------------
// Credit Note Creation Button Props
// ----------------------------------------

export const createCreditNoteForInvoiceButtonProps = ({
  invoiceType,
  associatedActiveWalletPresent,
  creditableAmountCents,
  refundableAmountCents,
  offsettableAmountCents,
}: Partial<Invoice>) => {
  const isAssociatedWithTerminatedWallet =
    invoiceType === InvoiceTypeEnum.Credit && !associatedActiveWalletPresent

  const disabledIssueCreditNoteButton = isCreditNoteCreationDisabled({
    creditableAmountCents,
    refundableAmountCents,
    offsettableAmountCents,
  })

  const getDisabledReason = (): keyof typeof TRANSLATIONS_MAP_ISSUE_CREDIT_NOTE_DISABLED => {
    if (isAssociatedWithTerminatedWallet) return 'terminatedWallet'
    return 'fullyCovered'
  }

  const disabledIssueCreditNoteButtonLabel =
    disabledIssueCreditNoteButton &&
    TRANSLATIONS_MAP_ISSUE_CREDIT_NOTE_DISABLED[getDisabledReason()]

  return {
    disabledIssueCreditNoteButton,
    disabledIssueCreditNoteButtonLabel,
  }
}

export const creditNoteFormHasAtLeastOneFeeChecked = (
  formValues: Partial<CreditNoteForm>,
): boolean => {
  const { fees, addOnFee, creditFee } = formValues
  const groupedFeesValues = Object.values(fees || {})

  if (addOnFee?.length) {
    return addOnFee?.some((aof) => {
      return aof?.checked
    })
  } else if (creditFee?.length) {
    return creditFee?.some((cf) => {
      return cf?.checked
    })
  } else if (groupedFeesValues.length) {
    return groupedFeesValues.some((fee) => {
      return fee?.fees?.some((f) => f?.checked)
    })
  }

  return false
}

// ----------------------------------------
// Initial PayBack Builder
// ----------------------------------------

/**
 * Builds the initial payBack array based on invoice payment status.
 * Determines which allocation options (credit, refund, offset) should be available.
 */
export const buildInitialPayBack = (
  invoice?: InvoiceForCreditNoteFormCalculationFragment | null,
): CreditNoteForm['payBack'] => {
  const totalPaidAmountCents = Number(invoice?.totalPaidAmountCents) || 0
  const totalDueAmountCents = Number(invoice?.totalDueAmountCents) || 0
  const hasPaymentDisputeLost = !!invoice?.paymentDisputeLostAt

  // Refund: available when there's been a payment and no dispute lost
  const hasRefund = totalPaidAmountCents > 0 && !hasPaymentDisputeLost
  // Offset: available when there's amount due > 0
  const hasOffset = totalDueAmountCents > 0

  return [
    { type: CreditTypeEnum.credit, value: undefined },
    ...(hasRefund ? [{ type: CreditTypeEnum.refund, value: undefined }] : []),
    ...(hasOffset ? [{ type: CreditTypeEnum.offset, value: undefined }] : []),
  ]
}

// ----------------------------------------
// Credit Note Fees Builder
// ----------------------------------------

type InvoiceFeeForCreditNote = {
  id: string
  amountCurrency: CurrencyEnum
  invoiceName?: string | null
  itemName?: string | null
  creditableAmountCents: string
  offsettableAmountCents: string
  appliedTaxes?: Array<{
    id: string
    taxName: string
    taxRate: number
  }> | null
}

/**
 * Converts invoice fees to credit note form fees (FromFee[]).
 * Used for add-on and credit invoice types where fees need to be mapped to the credit note form.
 *
 * @param fees - The invoice fees to convert
 * @param canCreditOrRefund - Whether the invoice has creditable/refundable amounts (determines which amount field to use)
 * @returns Array of FromFee objects for the credit note form, or empty array if no valid fees
 */
export const buildCreditNoteFees = (
  fees: InvoiceFeeForCreditNote[] | undefined | null,
  canCreditOrRefund: boolean,
): FromFee[] => {
  if (!fees) return []

  return fees.reduce<FromFee[]>((acc, fee) => {
    const amountCents = canCreditOrRefund ? fee.creditableAmountCents : fee.offsettableAmountCents

    if (Number(amountCents) > 0) {
      acc.push({
        id: fee.id,
        checked: true,
        value: deserializeAmount(amountCents, fee.amountCurrency),
        name: fee.invoiceName || fee.itemName || '',
        maxAmount: Number(amountCents),
        appliedTaxes: fee.appliedTaxes || [],
        isReadOnly: !canCreditOrRefund,
      })
    }

    return acc
  }, [])
}
