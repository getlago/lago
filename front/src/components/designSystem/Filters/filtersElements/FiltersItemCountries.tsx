import { MultipleComboBox } from '~/components/form'
import { CountryCodes } from '~/core/constants/countryCodes'
import { CountryCode } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemCountriesProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemCountries = ({ value, setFilterValue }: FiltersItemCountriesProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      forcePopupIcon
      disableClearable
      placeholder={translate('text_1759933141735g1r551m8os0')}
      data={Object.values(CountryCode).map((countryCode) => ({
        label: CountryCodes[countryCode],
        value: countryCode,
      }))}
      onChange={(country) => {
        setFilterValue(String(country.map((b) => b.value).join(',')))
      }}
      value={value
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => ({
          label: v,
          value: v,
        }))}
    />
  )
}
