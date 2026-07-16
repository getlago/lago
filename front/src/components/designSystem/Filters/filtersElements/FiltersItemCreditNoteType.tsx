import { MultipleComboBox } from '~/components/form'
import { CreditNoteTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemCreditNoteTypeProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

const CREDIT_NOTE_TYPES = [
  {
    type: CreditNoteTypeEnum.Credit,
    label: 'text_1727079454388x9q4uz6ah71',
  },
  {
    type: CreditNoteTypeEnum.Refund,
    label: 'text_17270794543889mcmuhfq70p',
  },
  {
    type: CreditNoteTypeEnum.Offset,
    label: 'text_1736431648426rjb1s8vq61n',
  },
]

export const FiltersItemCreditNoteType = ({
  value,
  setFilterValue,
}: FiltersItemCreditNoteTypeProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={CREDIT_NOTE_TYPES.map((type) => ({
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
          const creditNoteType = CREDIT_NOTE_TYPES.find((type) => type.type === v)

          return {
            value: v,
            label: creditNoteType ? translate(creditNoteType.label) : v,
          }
        })}
    />
  )
}
