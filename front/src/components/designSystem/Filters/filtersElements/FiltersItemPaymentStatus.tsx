import { MultipleComboBox } from '~/components/form'
import { InvoicePaymentStatusTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemPaymentStatusProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemPaymentStatus = ({
  value,
  setFilterValue,
}: FiltersItemPaymentStatusProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={[
        {
          label: translate('text_63e27c56dfe64b846474ef4e'),
          value: InvoicePaymentStatusTypeEnum.Failed,
        },
        {
          label: translate('text_62da6db136909f52c2704c30'),
          value: InvoicePaymentStatusTypeEnum.Pending,
        },
        {
          label: translate('text_63ac86d797f728a87b2f9fa1'),
          value: InvoicePaymentStatusTypeEnum.Succeeded,
        },
      ]}
      onChange={(invoiceType) => {
        setFilterValue(String(invoiceType.map((v) => v.value).join(',')))
      }}
      value={(value || '')
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => ({ value: v }))}
    />
  )
}
