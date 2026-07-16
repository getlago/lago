import { ComboBox } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemCustomerAccountTypeProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export enum IsCustomerTinEmptyEnum {
  True = 'true',
  False = 'false',
}

export const FiltersItemIsCustomerTinEmpty = ({
  value,
  setFilterValue,
}: FiltersItemCustomerAccountTypeProps) => {
  const { translate } = useInternationalization()

  return (
    <ComboBox
      disableClearable
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      sortValues={false}
      data={[
        {
          value: IsCustomerTinEmptyEnum.True,
          label: translate('text_17440181167432q7jzt9znuh'),
        },
        {
          value: IsCustomerTinEmptyEnum.False,
          label: translate('text_1744018116743ntlygtcnq95'),
        },
      ]}
      onChange={setFilterValue}
      value={value}
    />
  )
}
