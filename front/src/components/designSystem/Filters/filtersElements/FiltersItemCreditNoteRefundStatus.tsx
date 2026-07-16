import { MultipleComboBox } from '~/components/form'
import { CreditNoteRefundStatusEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemCreditNoteRefundStatusProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

const CREDIT_NOTE_REFUND_STATUSES = [
  {
    refundStatus: CreditNoteRefundStatusEnum.Succeeded,
    label: 'text_1734703891144fcw46jk9gzh',
  },
  {
    refundStatus: CreditNoteRefundStatusEnum.Pending,
    label: 'text_1734774653389j2meo530xlb',
  },
  {
    refundStatus: CreditNoteRefundStatusEnum.Failed,
    label: 'text_17347746533897mbptdz8x5k',
  },
]

export const FiltersItemCreditNoteRefundStatus = ({
  value,
  setFilterValue,
}: FiltersItemCreditNoteRefundStatusProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={CREDIT_NOTE_REFUND_STATUSES.map((refundStatus) => ({
        value: refundStatus.refundStatus,
        label: translate(refundStatus.label),
      }))}
      onChange={(refundStatuses) => {
        setFilterValue(String(refundStatuses.map((v) => v.value).join(',')))
      }}
      value={value
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => ({ value: v }))}
    />
  )
}
