import { MultipleComboBox } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemZipcodesProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemZipcodes = ({ value, setFilterValue }: FiltersItemZipcodesProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      disableClearable
      placeholder={translate('text_1759933204078h2854rr8kve')}
      data={[]}
      onChange={(zipcode) => {
        setFilterValue(String(zipcode.map((b) => b.value).join(',')))
      }}
      value={value
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => ({ value: v, label: v }))}
      freeSolo
    />
  )
}
