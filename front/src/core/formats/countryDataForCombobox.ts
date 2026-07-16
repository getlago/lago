import { BasicComboBoxData } from '~/components/form'
import { CountryCodes } from '~/core/constants/countryCodes'

export const countryDataForCombobox: BasicComboBoxData[] = (
  Object.keys(CountryCodes) as Array<keyof typeof CountryCodes>
).map((countryKey) => {
  return {
    value: countryKey,
    label: CountryCodes[countryKey],
  }
})
