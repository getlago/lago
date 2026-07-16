import { useMemo } from 'react'

import { useFilters } from '~/components/designSystem/Filters/useFilters'
import { MultipleComboBox } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useGetAllMembers } from '~/hooks/useGetAllMembers'

import { filterDataInlineSeparator, FiltersFormValues } from '../types'
import { escapeFilterLabel, unescapeFilterLabel } from '../utils'

type FiltersItemUserIdsProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemUserIds = ({ value, setFilterValue }: FiltersItemUserIdsProps) => {
  const { translate } = useInternationalization()
  const { memberships } = useGetAllMembers()
  const { displayInDialog } = useFilters()

  const comboboxUserIdsData = useMemo(() => {
    if (!memberships.length) return []

    return memberships
      .filter((membership) => !!membership.user.email)
      .map((membership) => ({
        label: membership.user.email as string,
        value: `${membership.user.id}${filterDataInlineSeparator}${escapeFilterLabel(
          membership.user.email ?? '',
        )}`,
      }))
  }, [memberships])

  return (
    <MultipleComboBox
      PopperProps={{ displayInDialog }}
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
      data={comboboxUserIdsData}
      onChange={(userIds) => {
        setFilterValue(String(userIds.map((v) => v.value).join(',')))
      }}
      value={(value ?? '')
        .split(',')
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
