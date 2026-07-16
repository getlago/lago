import { MultipleComboBox } from '~/components/form'
import { StatusEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemQuoteStatusProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemQuoteStatus = ({ value, setFilterValue }: FiltersItemQuoteStatusProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={[
        {
          label: translate('text_63ac86d797f728a87b2f9f91'),
          value: StatusEnum.Draft,
        },
        {
          label: translate('text_1775747115932eu6r3ejjoox'),
          value: StatusEnum.Approved,
        },
        {
          label: translate('text_6376641a2a9c70fff5bddcd5'),
          value: StatusEnum.Voided,
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
