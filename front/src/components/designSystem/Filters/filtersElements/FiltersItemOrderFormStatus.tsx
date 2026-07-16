import { MultipleComboBox } from '~/components/form'
import { OrderFormStatusEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemOrderFormStatusProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemOrderFormStatus = ({
  value,
  setFilterValue,
}: FiltersItemOrderFormStatusProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={[
        {
          label: translate('text_17766979384805q6wx9it6wa'),
          value: OrderFormStatusEnum.Generated,
        },
        {
          label: translate('text_1776697938480b1fi7wqtzyi'),
          value: OrderFormStatusEnum.Signed,
        },
        {
          label: translate('text_1776697938480ap28ussl837'),
          value: OrderFormStatusEnum.Expired,
        },
        {
          label: translate('text_1776697938480hzc1xsmmpez'),
          value: OrderFormStatusEnum.Voided,
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
