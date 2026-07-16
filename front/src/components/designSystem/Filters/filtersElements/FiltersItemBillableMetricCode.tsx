import { useMemo } from 'react'

import { ComboBox } from '~/components/form'
import { useBillableMetricsQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

type FiltersItemBillableMetricCodeProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemBillableMetricCode = ({
  value,
  setFilterValue,
}: FiltersItemBillableMetricCodeProps) => {
  const { translate } = useInternationalization()
  const { data } = useBillableMetricsQuery({
    variables: {
      limit: 100,
    },
  })

  const comboboxData = useMemo(() => {
    if (!data?.billableMetrics?.collection) return []

    return data.billableMetrics.collection.map((billableMetric) => ({
      label: billableMetric.code,
      value: `${billableMetric.code}`,
    }))
  }, [data])

  return (
    <ComboBox
      disableClearable
      placeholder={translate('text_1761554090907c9n5qyilqow')}
      data={comboboxData}
      onChange={(billableMetric) => setFilterValue(billableMetric)}
      value={value}
    />
  )
}
