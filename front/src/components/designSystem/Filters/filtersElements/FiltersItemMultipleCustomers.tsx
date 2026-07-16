import { gql } from '@apollo/client'
import { useMemo } from 'react'

import { useFilters } from '~/components/designSystem/Filters/useFilters'
import { Typography } from '~/components/designSystem/Typography'
import { ComboboxItem, MultipleComboBox } from '~/components/form'
import { useGetCustomersForFilterItemMultipleCustomersQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { filterDataInlineSeparator, FiltersFormValues } from '../types'
import { escapeFilterLabel, unescapeFilterLabel } from '../utils'

gql`
  query getCustomersForFilterItemMultipleCustomers($page: Int, $limit: Int) {
    customers(page: $page, limit: $limit, withDeleted: true) {
      metadata {
        currentPage
        totalPages
      }
      collection {
        id
        displayName
        externalId
        deletedAt
      }
    }
  }
`

type FiltersItemMultipleCustomersProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemMultipleCustomers = ({
  value,
  setFilterValue,
}: FiltersItemMultipleCustomersProps) => {
  const { translate } = useInternationalization()
  const { displayInDialog } = useFilters()

  const { data } = useGetCustomersForFilterItemMultipleCustomersQuery({
    variables: { page: 1, limit: 500 },
  })

  const comboboxCustomersData = useMemo(() => {
    if (!data?.customers?.collection) return []

    return data.customers.collection.map((customer) => {
      const customerName = customer?.displayName

      const customerInformationToDisplay = customerName || customer.externalId || ''
      const customerDeletedInformation = customer.deletedAt
        ? ` (${translate('text_1743158702704o1juwxmr4ab')})`
        : ''

      return {
        label: `${customerInformationToDisplay}${customerDeletedInformation}`,
        labelNode: (
          <ComboboxItem>
            <Typography variant="body" color="grey700" noWrap>
              {customerName || customer.externalId || ''}
            </Typography>
            {customer.deletedAt && (
              <Typography variant="caption" color="grey600" noWrap>
                {` (${translate('text_1743158702704o1juwxmr4ab')})`}
              </Typography>
            )}
          </ComboboxItem>
        ),
        value: `${customer.id}${filterDataInlineSeparator}${escapeFilterLabel(customerName ?? '')}`,
      }
    })
  }, [data?.customers?.collection, translate])

  return (
    <MultipleComboBox
      PopperProps={{ displayInDialog }}
      disableClearable
      disableCloseOnSelect
      placeholder={translate('text_63befc65efcd9374da45b801')}
      data={comboboxCustomersData}
      onChange={(customers) => {
        setFilterValue(String(customers.map((v) => v.value).join(',')))
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
