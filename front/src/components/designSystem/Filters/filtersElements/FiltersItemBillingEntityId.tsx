import { useMemo } from 'react'

import { ComboBox } from '~/components/form'
import { useGetBillingEntitiesQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { filterDataInlineSeparator, FiltersFormValues } from '../types'
import { escapeFilterLabel } from '../utils'

type FiltersItemBillingEntityIdProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

/**
 * Single-select counterpart to {@link FiltersItemBillingEntity}. Use when the
 * backend resolver expects a single `billing_entity_id` (e.g. analytics
 * resolvers like `gross_revenues`) rather than an array.
 *
 * Stores `${id}${filterDataInlineSeparator}${label}` so the chip displays the
 * entity name while the query var translator extracts the id.
 */
export const FiltersItemBillingEntityId = ({
  value,
  setFilterValue,
}: FiltersItemBillingEntityIdProps) => {
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
    <ComboBox
      disableClearable
      placeholder={translate('text_1743688264122ndlc0cpwtzd')}
      data={comboboxData}
      onChange={(billingEntity) => setFilterValue(billingEntity)}
      value={value}
    />
  )
}
