import { IconName } from 'lago-design-system'

import { StatusProps, StatusType } from '~/components/designSystem/Status'
import {
  InvoicePaymentStatusTypeEnum,
  InvoiceStatusTypeEnum,
  PayablePaymentStatusEnum,
} from '~/generated/graphql'

export const isInvoicePartiallyPaid = (
  totalPaidAmountCents?: string | number,
  totalDueAmountCents?: string | number,
): boolean => Number(totalPaidAmountCents) > 0 && Number(totalDueAmountCents) > 0

export const invoiceStatusMapping = ({
  status,
}: {
  status: InvoiceStatusTypeEnum
}): StatusProps => {
  switch (status) {
    case InvoiceStatusTypeEnum.Draft:
      return { label: 'draft', type: StatusType.outline }
    case InvoiceStatusTypeEnum.Failed:
      return { label: 'failed', type: StatusType.warning }
    case InvoiceStatusTypeEnum.Finalized:
      return { label: 'finalized', type: StatusType.success }
    case InvoiceStatusTypeEnum.Voided:
      return { label: 'voided', type: StatusType.disabled }
    case InvoiceStatusTypeEnum.Pending:
      return { label: 'pending', type: StatusType.default }
    default:
      return { label: 'n/a', type: StatusType.default }
  }
}

export const paymentStatusMapping = ({
  status,
  paymentStatus,
  totalPaidAmountCents,
  totalDueAmountCents,
}: {
  status?: InvoiceStatusTypeEnum
  paymentStatus?: InvoicePaymentStatusTypeEnum
  totalPaidAmountCents?: number
  totalDueAmountCents?: number
}): StatusProps => {
  const isPartiallyPaid = isInvoicePartiallyPaid(totalPaidAmountCents, totalDueAmountCents)

  const endIcon: IconName | undefined = isPartiallyPaid ? 'partially-filled' : undefined

  if (status === InvoiceStatusTypeEnum.Finalized) {
    switch (paymentStatus) {
      case InvoicePaymentStatusTypeEnum.Pending:
        return { label: 'pending', type: StatusType.default, endIcon }
      case InvoicePaymentStatusTypeEnum.Failed:
        return { label: 'failed', type: StatusType.warning, endIcon }
      case InvoicePaymentStatusTypeEnum.Succeeded:
        return { label: 'succeeded', type: StatusType.success, endIcon }

      default:
        return { label: 'n/a', type: StatusType.default, endIcon }
    }
  }

  return { label: 'n/a', type: StatusType.default, endIcon }
}

export const payablePaymentStatusMapping = ({
  payablePaymentStatus,
}: {
  payablePaymentStatus?: PayablePaymentStatusEnum
}): StatusProps => {
  switch (payablePaymentStatus) {
    case PayablePaymentStatusEnum.Pending:
      return { label: 'pending', type: StatusType.default }
    case PayablePaymentStatusEnum.Failed:
      return { label: 'failed', type: StatusType.warning }
    case PayablePaymentStatusEnum.Succeeded:
      return { label: 'succeeded', type: StatusType.success }
    case PayablePaymentStatusEnum.Processing:
      return { label: 'processing', type: StatusType.default }
    default:
      return { label: 'n/a', type: StatusType.default }
  }
}
