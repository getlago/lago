import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { intlFormatDateTime } from '~/core/timezone'
import { CurrencyEnum, PaymentTypeEnum, ProviderTypeEnum, TimezoneEnum } from '~/generated/graphql'

import { DocumentData } from './EmailPreview'

const PROVIDER_LABEL_KEYS: Record<ProviderTypeEnum, string> = {
  [ProviderTypeEnum.Stripe]: 'text_62b1edddbf5f461ab971277d',
  [ProviderTypeEnum.Adyen]: 'text_645d071272418a14c1c76a6d',
  [ProviderTypeEnum.Gocardless]: 'text_634ea0ecc6147de10ddb6625',
  [ProviderTypeEnum.Cashfree]: 'text_17367626793434wkg1rk0114',
  [ProviderTypeEnum.Flutterwave]: 'text_1749724395108m0swrna0zt4',
  [ProviderTypeEnum.Moneyhash]: 'text_1733427981129n3wxjui0bex',
}

const MANUAL_PAYMENT_LABEL_KEY = 'text_173799550683709p2rqkoqd5'

type FormatAmountInput = {
  amountCents: number | string | null | undefined
  currency: CurrencyEnum | null | undefined
}

const formatAmount = ({ amountCents, currency }: FormatAmountInput): string => {
  const cur = currency || CurrencyEnum.Usd

  return intlFormatNumber(deserializeAmount(amountCents || 0, cur), { currency: cur })
}

// --- Invoice ---

type InvoiceInput = {
  totalAmountCents?: number | string | null
  currency?: CurrencyEnum | null
  number?: string | null
  issuingDate?: string | null
}

export const buildInvoiceDocumentData = (
  invoice: InvoiceInput | undefined | null,
): DocumentData => {
  if (!invoice) return {}

  return {
    amount: formatAmount({ amountCents: invoice.totalAmountCents, currency: invoice.currency }),
    invoiceNumber: invoice.number ?? undefined,
    issueDate: invoice.issuingDate ? intlFormatDateTime(invoice.issuingDate).date : undefined,
  }
}

// --- Credit Note ---

type CreditNoteInput = {
  totalAmountCents?: number | string | null
  currency?: CurrencyEnum | null
  number?: string | null
  createdAt?: string | null
  invoice?: { number?: string | null } | null
}

export const buildCreditNoteDocumentData = (
  creditNote: CreditNoteInput | undefined | null,
): DocumentData => {
  if (!creditNote) return {}

  return {
    amount: formatAmount({
      amountCents: creditNote.totalAmountCents,
      currency: creditNote.currency,
    }),
    creditNoteNumber: creditNote.number ?? undefined,
    invoiceNumber: creditNote.invoice?.number ?? undefined,
    issueDate: creditNote.createdAt ? intlFormatDateTime(creditNote.createdAt).date : undefined,
  }
}

// --- Payment Receipt ---

type PaymentInvoice = {
  number: string
  totalAmountCents?: number | string | null
  currency?: CurrencyEnum | null
}

type PaymentInput = {
  amountCents?: number | string | null
  amountCurrency?: CurrencyEnum | null
  createdAt?: string | null
  paymentType?: PaymentTypeEnum | null
  paymentProviderType?: ProviderTypeEnum | null
  paymentReceipt?: { number?: string | null } | null
  invoices: PaymentInvoice[]
  timezone?: TimezoneEnum | null
  translate: (key: string) => string
}

export const buildPaymentDocumentData = ({
  amountCents,
  amountCurrency,
  createdAt,
  paymentType,
  paymentProviderType,
  paymentReceipt,
  invoices,
  timezone,
  translate,
}: PaymentInput): DocumentData => {
  const formattedAmount = formatAmount({ amountCents, currency: amountCurrency })

  let paymentMethod: string | undefined

  if (paymentType === PaymentTypeEnum.Manual) {
    paymentMethod = translate(MANUAL_PAYMENT_LABEL_KEY)
  } else if (paymentProviderType) {
    paymentMethod = translate(PROVIDER_LABEL_KEYS[paymentProviderType])
  }

  return {
    amount: formattedAmount,
    receiptNumber: paymentReceipt?.number ?? undefined,
    paymentDate: createdAt ? intlFormatDateTime(createdAt, { timezone }).date : undefined,
    paymentMethod,
    amountPaid: formattedAmount,
    invoices: invoices.map((inv) => ({
      number: inv.number,
      amount:
        inv.totalAmountCents !== null
          ? formatAmount({ amountCents: inv.totalAmountCents, currency: inv.currency })
          : '',
    })),
  }
}
