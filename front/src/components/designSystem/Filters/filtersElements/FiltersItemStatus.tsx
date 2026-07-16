import { MultipleComboBox } from '~/components/form'
import { InvoiceStatusTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemStatusProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemStatus = ({ value, setFilterValue }: FiltersItemStatusProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={[
        {
          label: translate('text_63ac86d797f728a87b2f9f91'),
          value: InvoiceStatusTypeEnum.Draft,
        },
        {
          label: translate('text_63e27c56dfe64b846474ef4e'),
          value: InvoiceStatusTypeEnum.Failed,
        },
        {
          label: translate('text_65269c2e471133226211fd74'),
          value: InvoiceStatusTypeEnum.Finalized,
        },
        {
          label: translate('text_62da6db136909f52c2704c30'),
          value: InvoiceStatusTypeEnum.Pending,
        },
        {
          label: translate('text_6376641a2a9c70fff5bddcd5'),
          value: InvoiceStatusTypeEnum.Voided,
        },
      ]}
      onChange={(status) => {
        setFilterValue(String(status.map((v) => v.value).join(',')))
      }}
      value={value
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => ({ value: v }))}
    />
  )
}
