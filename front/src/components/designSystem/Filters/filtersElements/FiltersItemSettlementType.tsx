import { MultipleComboBox } from '~/components/form'
import { InvoiceSettlementTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemSettlementTypeProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

const SETTLEMENT_TYPES = [
  {
    type: InvoiceSettlementTypeEnum.CreditNote,
    label: 'text_1748341883774iypsrgem3hr',
  },
]

export const FiltersItemSettlementType = ({
  value,
  setFilterValue,
}: FiltersItemSettlementTypeProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={SETTLEMENT_TYPES.map((type) => ({
        value: type.type,
        label: translate(type.label),
      }))}
      onChange={(types) => {
        setFilterValue(String(types.map((v) => v.value).join(',')))
      }}
      value={value
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => {
          const settlementType = SETTLEMENT_TYPES.find((type) => type.type === v)

          return {
            value: v,
            label: settlementType ? translate(settlementType.label) : v,
          }
        })}
    />
  )
}
