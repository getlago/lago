import { MultipleComboBox } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemOrderFormNumberProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemOrderFormNumber = ({
  value,
  setFilterValue,
}: FiltersItemOrderFormNumberProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      freeSolo
      disableClearable
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={[]}
      onChange={(numbers) => {
        setFilterValue(String(numbers.map((v) => v.value).join(',')))
      }}
      value={value
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => ({ value: v }))}
    />
  )
}
