import { useMemo } from 'react'

import { MultipleComboBox } from '~/components/form'
import { useGetBillingEntitiesQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { filterDataInlineSeparator, FiltersFormValues } from '../types'
import { escapeFilterLabel, unescapeFilterLabel } from '../utils'

type FiltersItemBillingEntityProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemBillingEntity = ({
  value,
  setFilterValue,
}: FiltersItemBillingEntityProps) => {
  const { translate } = useInternationalization()
  const { data } = useGetBillingEntitiesQuery()

  const comboboxData = useMemo(() => {
    if (!data?.billingEntities?.collection) return []

    return data.billingEntities.collection.map((billingEntity) => ({
      label: billingEntity.name || billingEntity.code,
      value: `${billingEntity.id}${filterDataInlineSeparator}${escapeFilterLabel(
        billingEntity.name || billingEntity.code,
      )}`,
    }))
  }, [data])

  return (
    <MultipleComboBox
      disableClearable
      placeholder={translate('text_1743688264122ndlc0cpwtzd')}
      data={comboboxData}
      onChange={(billingEntity) => {
        setFilterValue(String(billingEntity.map((b) => b.value).join(',')))
      }}
      value={value
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => ({
          label: unescapeFilterLabel(
            v.split(filterDataInlineSeparator)[1] || v.split(filterDataInlineSeparator)[0],
          ),
          value: v,
        }))}
    />
  )
}
