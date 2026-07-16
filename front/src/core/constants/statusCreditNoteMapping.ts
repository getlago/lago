import { StatusProps, StatusType } from '~/components/designSystem/Status'
import { CreditNoteCreditStatusEnum, CreditNoteRefundStatusEnum } from '~/generated/graphql'

export const creditNoteCreditStatusMapping = (
  type?: CreditNoteCreditStatusEnum | null | undefined,
): StatusProps => {
  switch (type) {
    case CreditNoteCreditStatusEnum.Consumed:
      return {
        type: StatusType.danger,
        label: 'consumed',
      }
    case CreditNoteCreditStatusEnum.Voided:
      return {
        type: StatusType.danger,
        label: 'voided',
      }
    default:
      return {
        type: StatusType.success,
        label: 'available',
      }
  }
}

export const creditNoteRefundStatusMapping = (
  type?: CreditNoteRefundStatusEnum | null | undefined,
): StatusProps => {
  switch (type) {
    case CreditNoteRefundStatusEnum.Succeeded:
      return {
        type: StatusType.success,
        label: 'refunded',
      }
    case CreditNoteRefundStatusEnum.Failed:
      return {
        type: StatusType.warning,
        label: 'failed',
      }
    default:
      return {
        type: StatusType.default,
        label: 'pending',
      }
  }
}
