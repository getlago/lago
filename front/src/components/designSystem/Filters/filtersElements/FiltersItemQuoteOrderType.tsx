import { MultipleComboBox } from '~/components/form'
import { OrderTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemQuoteOrderTypeProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemQuoteOrderType = ({
  value,
  setFilterValue,
}: FiltersItemQuoteOrderTypeProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={[
        {
          label: translate('text_1775747115932ib2to4erkoo'),
          value: OrderTypeEnum.OneOff,
        },
        {
          label: translate('text_17757471159329jnt7pyy6vr'),
          value: OrderTypeEnum.SubscriptionAmendment,
        },
        {
          label: translate('text_1775747115932u8ttc3l11w1'),
          value: OrderTypeEnum.SubscriptionCreation,
        },
      ]}
      onChange={(orderTypes) => {
        setFilterValue(String(orderTypes.map((v) => v.value).join(',')))
      }}
      value={value
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => ({ value: v }))}
    />
  )
}
