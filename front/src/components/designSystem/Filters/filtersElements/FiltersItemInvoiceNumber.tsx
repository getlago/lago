import { gql } from '@apollo/client'
import { useMemo } from 'react'

import { ComboBox } from '~/components/form'
import { useGetInvoiceNumbersForFilterItemInvoiceNumbersLazyQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersFormValues } from '../types'

gql`
  query getInvoiceNumbersForFilterItemInvoiceNumbers($page: Int, $limit: Int, $searchTerm: String) {
    invoices(page: $page, limit: $limit, searchTerm: $searchTerm) {
      metadata {
        currentPage
        totalPages
      }
      collection {
        id
        number
      }
    }
  }
`

type FiltersItemInvoiceNumberProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

export const FiltersItemInvoiceNumber = ({
  value,
  setFilterValue,
}: FiltersItemInvoiceNumberProps) => {
  const { translate } = useInternationalization()
  const [getInvoiceNumbers, { data, loading }] =
    useGetInvoiceNumbersForFilterItemInvoiceNumbersLazyQuery({
      variables: { page: 1, limit: 10 },
    })

  const comboboxInvoiceNumbersData = useMemo(() => {
    if (!data?.invoices?.collection) return []

    return data.invoices?.collection.map((invoice) => {
      const { number } = invoice

      return {
        label: number,
        value: number,
      }
    })
  }, [data])

  return (
    <ComboBox
      disableClearable
      searchQuery={getInvoiceNumbers}
      loading={loading}
      placeholder={translate('text_1734698875218e1up0le97tu')}
      data={comboboxInvoiceNumbersData}
      onChange={(invoiceNumberValue) => setFilterValue(invoiceNumberValue)}
      value={value}
    />
  )
}
