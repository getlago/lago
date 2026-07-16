import { ComboBox } from '~/components/form'
import { CustomerAccountTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemCustomerAccountTypeProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemCustomerAccountType = ({
  value,
  setFilterValue,
}: FiltersItemCustomerAccountTypeProps) => {
  const { translate } = useInternationalization()

  return (
    <ComboBox
      disableClearable
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={[
        {
          value: CustomerAccountTypeEnum.Customer,
          label: translate('text_65201c5a175a4b0238abf29a'),
        },
        {
          value: CustomerAccountTypeEnum.Partner,
          label: translate('text_1738322099641hkzihmx9qyw'),
        },
      ]}
      onChange={setFilterValue}
      value={value}
    />
  )
}
