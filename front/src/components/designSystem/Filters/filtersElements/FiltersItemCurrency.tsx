import { ComboBox } from '~/components/form'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemCurrencyProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemCurrency = ({ value, setFilterValue }: FiltersItemCurrencyProps) => {
  const { translate } = useInternationalization()

  return (
    <ComboBox
      disableClearable
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={Object.values(CurrencyEnum).map((currency) => ({
        value: currency,
      }))}
      onChange={(currency) => setFilterValue(currency)}
      value={value}
    />
  )
}
