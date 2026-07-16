import { MultipleComboBox } from '~/components/form'
import { CreditNoteCreditStatusEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemCreditNoteCreditStatusProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

const CREDIT_NOTE_CREDIT_STATUSES = [
  {
    status: CreditNoteCreditStatusEnum.Available,
    label: 'text_637655cb50f04bf1c8379d0c',
  },
  {
    status: CreditNoteCreditStatusEnum.Consumed,
    label: 'text_6376641a2a9c70fff5bddcd1',
  },
  {
    status: CreditNoteCreditStatusEnum.Voided,
    label: 'text_6376641a2a9c70fff5bddcd5',
  },
]

export const FiltersItemCreditNoteCreditStatus = ({
  value,
  setFilterValue,
}: FiltersItemCreditNoteCreditStatusProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={CREDIT_NOTE_CREDIT_STATUSES.map((status) => ({
        value: status.status,
        label: translate(status.label),
      }))}
      onChange={(statuses) => {
        setFilterValue(String(statuses.map((v) => v.value).join(',')))
      }}
      value={value
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => ({ value: v }))}
    />
  )
}
