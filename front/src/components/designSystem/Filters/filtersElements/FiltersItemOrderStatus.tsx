import { MultipleComboBox } from '~/components/form'
import { OrderStatusEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemOrderStatusProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemOrderStatus = ({ value, setFilterValue }: FiltersItemOrderStatusProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={[
        {
          label: translate('text_1782392058759gdepj0tu2cn'),
          value: OrderStatusEnum.Created,
        },
        {
          label: translate('text_17823920587590tcd0ckxjde'),
          value: OrderStatusEnum.Executed,
        },
      ]}
      onChange={(statuses) => {
        setFilterValue(String(statuses.map((v) => v.value).join(',')))
      }}
      value={value
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => ({ value: v }))}
    />
  )
}
