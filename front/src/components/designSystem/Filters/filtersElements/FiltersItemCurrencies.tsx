import { MultipleComboBox } from '~/components/form'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { filterDataInlineSeparator, FiltersFormValues } from '../types'

type FiltersItemCurrenciesProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemCurrencies = ({ value, setFilterValue }: FiltersItemCurrenciesProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      forcePopupIcon
      disableClearable
      placeholder={translate('text_1759933204078d8saqn06pdf')}
      data={Object.values(CurrencyEnum).map((currency) => ({
        value: currency,
      }))}
      onChange={(currency) => {
        setFilterValue(String(currency.map((b) => b.value).join(',')))
      }}
      value={value
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => ({
          label: v.split(filterDataInlineSeparator)[1] || v.split(filterDataInlineSeparator)[0],
          value: v,
        }))}
    />
  )
}
