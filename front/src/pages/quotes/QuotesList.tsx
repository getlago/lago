import { useMemo } from 'react'
import { generatePath, useSearchParams } from 'react-router-dom'

import { formatFiltersForQuotesQuery } from '~/components/designSystem/Filters'
import { QuoteDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { QUOTE_DETAILS_ROUTE } from '~/core/router'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { QuotesSectionTable } from './common/QuotesSectionTable'
import { useQuotesColumns } from './common/useQuotesColumns'
import { useQuotes } from './hooks/useQuotes'
import { useQuoteVersionActions } from './hooks/useQuoteVersionActions'

const QuotesList = (): JSX.Element => {
  const { translate } = useInternationalization()
  const [searchParams] = useSearchParams()

  const filtersForQuotesQuery = useMemo(
    () => formatFiltersForQuotesQuery(searchParams),
    [searchParams],
  )

  const { quotes, loading, error, fetchMore, metadata } = useQuotes({
    ...filtersForQuotesQuery,
  })
  const { getActions } = useQuoteVersionActions()
  const columns = useQuotesColumns()

  return (
    <QuotesSectionTable
      name="quotes-list"
      className="max-w-full"
      containerClassName="border-t border-grey-300"
      data={quotes}
      isLoading={loading}
      hasError={!!error}
      metadata={metadata}
      fetchMore={fetchMore}
      columns={columns}
      getActions={(quote) => getActions(quote)}
      onRowActionLink={({ id }) =>
        generatePath(QUOTE_DETAILS_ROUTE, {
          quoteId: id,
          tab: QuoteDetailsTabsOptionsEnum.overview,
        })
      }
      emptyState={{
        title: translate('text_17757391860814p20fr87x9g'),
        subtitle: translate('text_177573918608169w9wthupaz'),
      }}
    />
  )
}

export default QuotesList
