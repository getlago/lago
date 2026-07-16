import { MultipleComboBox } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemStatesProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemStates = ({ value, setFilterValue }: FiltersItemStatesProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      disableClearable
      placeholder={translate('text_1759933204078u1tne7oow48')}
      data={[]}
      onChange={(state) => {
        setFilterValue(String(state.map((b) => b.value).join(',')))
      }}
      value={value
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => ({ value: v, label: v }))}
      freeSolo
    />
  )
}
