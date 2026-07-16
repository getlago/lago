import { MultipleComboBox } from '~/components/form'
import { InvoiceTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemInvoiceTypeProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemInvoiceType = ({ value, setFilterValue }: FiltersItemInvoiceTypeProps) => {
  const { translate } = useInternationalization()

  return (
    <MultipleComboBox
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={[
        {
          label: translate('text_1733136185960mb0c4wf2ekq'),
          value: InvoiceTypeEnum.AddOn,
        },
        {
          label: translate('text_1728472697691y39tdxgyrcg'),
          value: InvoiceTypeEnum.AdvanceCharges,
        },
        {
          label: translate('text_62d18855b22699e5cf55f879'),
          value: InvoiceTypeEnum.Credit,
        },
        {
          label: translate('text_17331361859605azhkvgofv3'),
          value: InvoiceTypeEnum.OneOff,
        },
        {
          label: translate('text_1724179887722baucvj7bvc1'),
          value: InvoiceTypeEnum.ProgressiveBilling,
        },
        {
          label: translate('text_1728472697691k6k2e9m5ibb'),
          value: InvoiceTypeEnum.Subscription,
        },
      ]}
      onChange={(invoiceType) => {
        setFilterValue(String(invoiceType.map((v) => v.value).join(',')))
      }}
      value={value
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => ({ value: v }))}
    />
  )
}
