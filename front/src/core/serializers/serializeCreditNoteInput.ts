import { CreditNoteForm, CreditTypeEnum, FeesPerInvoice } from '~/components/creditNote/types'
import { serializeAmount } from '~/core/serializers/serializeAmount'
import {
  CreateCreditNoteInput,
  CreditNoteItemInput,
  CreditNoteReasonEnum,
  CurrencyEnum,
} from '~/generated/graphql'

export const serializeCreditNoteInput: (
  invoiceId: string,
  formValues: CreditNoteForm,
  currency: CurrencyEnum,
) => CreateCreditNoteInput = (invoiceId, formValues, currency) => {
  const { reason, description, payBack, fees = [], addOnFee, creditFee, metadata } = formValues

  return {
    invoiceId: invoiceId as string,
    reason: reason as CreditNoteReasonEnum,
    description: description,
    creditAmountCents: !payBack
      ? 0
      : serializeAmount(
          payBack.find((p) => p.type === CreditTypeEnum.credit)?.value || 0,
          currency,
        ),
    refundAmountCents: !payBack
      ? 0
      : serializeAmount(
          payBack.find((p) => p.type === CreditTypeEnum.refund)?.value || 0,
          currency,
        ) || 0,
    offsetAmountCents: !payBack
      ? 0
      : serializeAmount(
          payBack.find((p) => p.type === CreditTypeEnum.offset)?.value || 0,
          currency,
        ) || 0,
    items: [
      ...(addOnFee?.reduce<CreditNoteItemInput[]>((acc, fee) => {
        if (fee.checked && Number(fee.value) > 0) {
          acc.push({
            feeId: fee.id,
            amountCents: serializeAmount(fee.value, currency),
          })
        }

        return acc
      }, []) || []),
      ...(creditFee?.reduce<CreditNoteItemInput[]>((acc, fee) => {
        if (fee.checked && Number(fee.value) > 0) {
          acc.push({
            feeId: fee.id,
            amountCents: serializeAmount(fee.value, currency),
          })
        }

        return acc
      }, []) || []),
      ...Object.keys(fees).reduce<CreditNoteItemInput[]>((subAcc, subKey) => {
        const subChild = (fees as FeesPerInvoice)[subKey]

        return [
          ...subAcc,
          ...(subChild?.fees?.reduce<CreditNoteItemInput[]>((feeAcc, fee) => {
            if (!fee.checked || Number(fee.value) <= 0) {
              return feeAcc
            }

            return [
              ...feeAcc,
              {
                feeId: fee.id,
                amountCents: serializeAmount(fee.value, currency),
              },
            ]
          }, []) || []),
        ]
      }, []),
    ],
    metadata,
  }
}
