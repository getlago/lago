import { useMemo } from 'react'
import { generatePath, useSearchParams } from 'react-router-dom'

import { formatFiltersForOrderFormsQuery } from '~/components/designSystem/Filters'
import { ORDER_FORM_DETAILS_ROUTE, SIGN_ORDER_FORM_ROUTE } from '~/core/router'
import { OrderFormListItemFragment, OrderFormStatusEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { QuotesSectionTable } from './common/QuotesSectionTable'
import { useOrderFormsColumns } from './common/useOrderFormsColumns'
import { useOrderFormActions } from './hooks/useOrderFormActions'
import { useOrderForms } from './hooks/useOrderForms'

interface OrderFormsListProps {
  quoteNumber?: string
}

const OrderFormsList = ({ quoteNumber }: OrderFormsListProps): JSX.Element => {
  const { translate } = useInternationalization()
  const [searchParams] = useSearchParams()

  const filtersForOrderFormsQuery = useMemo(
    () => formatFiltersForOrderFormsQuery(searchParams),
    [searchParams],
  )

  const { orderForms, loading, error, fetchMore, metadata } = useOrderForms({
    ...filtersForOrderFormsQuery,
    ...(quoteNumber ? { quoteNumber: [quoteNumber] } : {}),
  })
  const { getActions } = useOrderFormActions()
  const columns = useOrderFormsColumns()

  const getRowLink = (orderForm: OrderFormListItemFragment): string =>
    orderForm.status === OrderFormStatusEnum.Generated
      ? generatePath(SIGN_ORDER_FORM_ROUTE, { orderFormId: orderForm.id })
      : generatePath(ORDER_FORM_DETAILS_ROUTE, { orderFormId: orderForm.id })

  return (
    <QuotesSectionTable
      name="order-forms-list"
      data={orderForms}
      isLoading={loading}
      hasError={!!error}
      metadata={metadata}
      fetchMore={fetchMore}
      columns={columns}
      getActions={(orderForm) => getActions(orderForm)}
      onRowActionLink={getRowLink}
      emptyState={{
        title: translate('text_1776697938480e54yje9i5aa'),
        subtitle: translate('text_17766979384803pz48gknynl'),
      }}
    />
  )
}

export default OrderFormsList
