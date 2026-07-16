import { StatusProps, StatusType } from '~/components/designSystem/Status'
import { StatusEnum } from '~/generated/graphql'

export const getQuoteStatusMapping = (
  status: StatusEnum,
  translate: (key: string) => string,
): Pick<StatusProps, 'type' | 'label'> => {
  switch (status) {
    case StatusEnum.Draft:
      return { type: StatusType.outline, label: 'draft' as const }
    case StatusEnum.Approved:
      return { type: StatusType.success, label: translate('text_1775747115932eu6r3ejjoox') }
    case StatusEnum.Voided:
      return { type: StatusType.disabled, label: 'voided' as const }
    default:
      return { type: StatusType.outline, label: status }
  }
}
