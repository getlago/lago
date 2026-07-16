import { useMemo } from 'react'

import { MultipleComboBox } from '~/components/form'
import { StatusTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemSubscriptionStatusProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

const subscriptionStatusMapping = (status?: StatusTypeEnum | null): string => {
  switch (status) {
    case StatusTypeEnum.Active:
      return 'text_624efab67eb2570101d1180e'
    case StatusTypeEnum.Pending:
      return 'text_1734774653389j2meo530xlb'
    case StatusTypeEnum.Incomplete:
      return 'text_1779882021466dr07sleoyk9'
    case StatusTypeEnum.Canceled:
      return 'text_17429854230668s8zhn9ujq6'
    case StatusTypeEnum.Terminated:
      return 'text_62e2a2f2a79d60429eff3035'
    default:
      return ''
  }
}

export const FiltersItemSubscriptionStatus = ({
  value,
  setFilterValue,
}: FiltersItemSubscriptionStatusProps) => {
  const { translate } = useInternationalization()

  const options = useMemo(
    () =>
      Object.values(StatusTypeEnum).map((v) => ({
        value: v,
        label: translate(subscriptionStatusMapping(v)),
      })),
    [translate],
  )

  return (
    <MultipleComboBox
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={options}
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
