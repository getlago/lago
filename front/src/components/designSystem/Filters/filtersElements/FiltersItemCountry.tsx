import { ComboBox } from '~/components/form'
import { CountryCodes } from '~/core/constants/countryCodes'
import { CountryCode } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemCountryProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemCountry = ({ value, setFilterValue }: FiltersItemCountryProps) => {
  const { translate } = useInternationalization()

  return (
    <ComboBox
      disableClearable
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={Object.values(CountryCode).map((countryCode) => ({
        label: CountryCodes[countryCode],
        value: countryCode,
      }))}
      onChange={(currency) => setFilterValue(currency)}
      value={value}
    />
  )
}
