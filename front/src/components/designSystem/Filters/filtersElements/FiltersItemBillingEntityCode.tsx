import { useMemo } from 'react'

import { ComboBox } from '~/components/form'
import { useGetBillingEntitiesQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemBillingEntityCodeProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemBillingEntityCode = ({
  value,
  setFilterValue,
}: FiltersItemBillingEntityCodeProps) => {
  const { translate } = useInternationalization()
  const { data } = useGetBillingEntitiesQuery()

  const comboboxData = useMemo(() => {
    if (!data?.billingEntities?.collection) return []

    return data.billingEntities.collection.map((billingEntity) => ({
      label: billingEntity.code,
      value: `${billingEntity.code}`,
    }))
  }, [data])

  return (
    <ComboBox
      disableClearable
      placeholder={translate('text_1747986312361n5x5h0ditd4')}
      data={comboboxData}
      onChange={(billingEntity) => setFilterValue(billingEntity)}
      value={value}
    />
  )
}
