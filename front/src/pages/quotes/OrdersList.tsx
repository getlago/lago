import { useMemo } from 'react'
import { useSearchParams } from 'react-router-dom'

import { formatFiltersForOrdersQuery } from '~/components/designSystem/Filters'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { QuotesSectionTable } from './common/QuotesSectionTable'
import { useOrdersColumns } from './common/useOrdersColumns'
import { useOrderActions } from './hooks/useOrderActions'
import { useOrders } from './hooks/useOrders'

interface OrdersListProps {
  quoteNumber?: string
}

const OrdersList = ({ quoteNumber }: OrdersListProps): JSX.Element => {
  const { translate } = useInternationalization()
  const [searchParams] = useSearchParams()

  const filtersForOrdersQuery = useMemo(
    () => formatFiltersForOrdersQuery(searchParams),
    [searchParams],
  )

  const defaultFilters = {
    ...filtersForOrdersQuery,
  }

  const { orders, loading, error, fetchMore, metadata } = useOrders(
    quoteNumber ? { ...defaultFilters, quoteNumber: [quoteNumber] } : defaultFilters,
  )
  const { getActions } = useOrderActions()

  const columns = useOrdersColumns({ hideSourceQuote: !!quoteNumber })

  return (
    <QuotesSectionTable
      name="orders-list"
      data={orders}
      isLoading={loading}
      hasError={!!error}
      metadata={metadata}
      fetchMore={fetchMore}
      columns={columns}
      emptyState={{
        title: translate('text_1782392058759fvp6ye50x8g'),
        subtitle: translate('text_1782392058759ee7h86svmtj'),
      }}
      getActions={(order) => getActions(order)}
    />
  )
}

export default OrdersList
