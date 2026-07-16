import { MultipleComboBox } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { CREDIT_NOTE_REASONS } from '~/pages/createCreditNote/CreateCreditNote'

import { FiltersFormValues } from '../types'

type FiltersItemCreditNoteReasonProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemCreditNoteReason = ({
  value,
  setFilterValue,
}: FiltersItemCreditNoteReasonProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={CREDIT_NOTE_REASONS.map((reason) => ({
        value: reason.reason,
        label: translate(reason.label),
      }))}
      onChange={(reasons) => {
        setFilterValue(String(reasons.map((v) => v.value).join(',')))
      }}
      value={value
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => ({ value: v }))}
    />
  )
}
