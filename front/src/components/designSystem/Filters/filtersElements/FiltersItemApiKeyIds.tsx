import { gql } from '@apollo/client'
import { useMemo } from 'react'

import { useFilters } from '~/components/designSystem/Filters/useFilters'
import { MultipleComboBox } from '~/components/form'
import { useGetApiKeyIdsForFilterItemApiKeyIdsQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { filterDataInlineSeparator, FiltersFormValues } from '../types'
import { escapeFilterLabel, unescapeFilterLabel } from '../utils'

gql`
  query getApiKeyIdsForFilterItemApiKeyIds {
    apiKeys {
      collection {
        id
        value
      }
    }
  }
`

type FiltersItemApiKeyIdsProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemApiKeyIds = ({ value, setFilterValue }: FiltersItemApiKeyIdsProps) => {
  const { translate } = useInternationalization()
  const { data } = useGetApiKeyIdsForFilterItemApiKeyIdsQuery()
  const { displayInDialog } = useFilters()

  const comboboxApiKeyIdsData = useMemo(() => {
    if (!data?.apiKeys?.collection) return []

    return data.apiKeys.collection.map((apiKey) => ({
      label: apiKey.value,
      value: `${apiKey.id}${filterDataInlineSeparator}${escapeFilterLabel(apiKey.value)}`,
    }))
  }, [data?.apiKeys?.collection])

  return (
    <MultipleComboBox
      PopperProps={{ displayInDialog }}
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={comboboxApiKeyIdsData}
      onChange={(apiKeyIds) => {
        setFilterValue(String(apiKeyIds.map((v) => v.value).join(',')))
      }}
      value={value
        ?.split(',')
        .filter((v) => !!v)
        .map((v) => ({
          label: unescapeFilterLabel(v.split(filterDataInlineSeparator)[1] ?? ''),
          value: v,
        }))}
    />
  )
}
