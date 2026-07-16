import { TRANSLATIONS_MAP_CUSTOMER_TYPE } from '~/components/customers/utils'
import { ComboBox } from '~/components/form'
import { CustomerTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemCustomerTypeProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemCustomerType = ({
  value,
  setFilterValue,
}: FiltersItemCustomerTypeProps) => {
  const { translate } = useInternationalization()

  return (
    <ComboBox
      disableClearable
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={[
        {
          value: CustomerTypeEnum.Company,
          label: translate(TRANSLATIONS_MAP_CUSTOMER_TYPE[CustomerTypeEnum.Company]),
        },
        {
          value: CustomerTypeEnum.Individual,
          label: translate(TRANSLATIONS_MAP_CUSTOMER_TYPE[CustomerTypeEnum.Individual]),
        },
      ]}
      onChange={setFilterValue}
      value={value}
    />
  )
}
