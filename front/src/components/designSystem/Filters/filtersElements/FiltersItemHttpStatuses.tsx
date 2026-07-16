import { useFilters } from '~/components/designSystem/Filters/useFilters'
import { MultipleComboBox } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemHttpStatusesProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

// TODO: Add enum when available
const API_LOG_STATUSES = [
  {
    value: 'succeeded',
    label: 'text_63e27c56dfe64b846474ef4d',
  },
  {
    value: 'failed',
    label: 'text_63e27c56dfe64b846474ef4e',
  },
]

export const FiltersItemHttpStatuses = ({
  value,
  setFilterValue,
}: FiltersItemHttpStatusesProps) => {
  const { translate } = useInternationalization()
  const { displayInDialog } = useFilters()

  return (
    <MultipleComboBox
      PopperProps={{ displayInDialog }}
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={API_LOG_STATUSES.map((status) => ({
        value: status.value,
        label: translate(status.label),
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
