import { MultipleComboBox } from '~/components/form'
import { OrderExecutionModeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemOrderExecutionModeProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemOrderExecutionMode = ({
  value,
  setFilterValue,
}: FiltersItemOrderExecutionModeProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={[
        {
          label: translate('text_1782392058759vsncvwa3829'),
          value: OrderExecutionModeEnum.ExecuteInLago,
        },
        {
          label: translate('text_1782392058759l2hdxjsbklc'),
          value: OrderExecutionModeEnum.OrderOnly,
        },
      ]}
      onChange={(modes) => {
        setFilterValue(String(modes.map((v) => v.value).join(',')))
      }}
      value={value
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => ({ value: v }))}
    />
  )
}
