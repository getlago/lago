import { ComboBox } from '~/components/form'
import {
  AnalyticsPeriodScopeEnum,
  PeriodScopeTranslationLookup,
} from '~/components/graphs/MonthSelectorDropdown'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemPeriodProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemPeriod = ({ value, setFilterValue }: FiltersItemPeriodProps) => {
  const { translate } = useInternationalization()

  const options = [
    AnalyticsPeriodScopeEnum.Year,
    AnalyticsPeriodScopeEnum.Quarter,
    AnalyticsPeriodScopeEnum.Month,
  ].map((period) => ({
    value: period,
    label: translate(PeriodScopeTranslationLookup[period]),
  }))

  return (
    <ComboBox
      disableClearable
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={options}
      onChange={setFilterValue}
      value={value}
    />
  )
}
