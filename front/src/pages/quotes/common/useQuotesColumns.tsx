import { Status } from '~/components/designSystem/Status'
import { TableColumn } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { QuoteListItemFragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { getQuoteOrderTypeTranslationKey } from './getQuoteOrderTypeTranslationKey'
import { getQuoteStatusMapping } from './getQuoteStatusMapping'
import { useSharedColumns } from './sharedColumns'

export const useQuotesColumns = (): Array<TableColumn<QuoteListItemFragment>> => {
  const { translate } = useInternationalization()
  const { getNumberColumn, getCustomerColumn, getCreatedAtColumn } = useSharedColumns()

  return [
    getNumberColumn<QuoteListItemFragment>('text_1775746196826pyjlfqx3anr'),
    getCustomerColumn<QuoteListItemFragment>(),
    {
      key: 'versions.0.status',
      title: translate('text_63ac86d797f728a87b2f9fa7'),
      minWidth: 100,
      content: ({ versions }) => {
        const status = versions[0]?.status

        if (!status) return null

        return <Status {...getQuoteStatusMapping(status, translate)} />
      },
    },
    {
      key: 'versions.0.version',
      title: translate('text_1775747115932pql5mtb30dc'),
      minWidth: 80,
      textAlign: 'right',
      content: ({ versions }) => (
        <Typography color="grey600">{versions[0]?.version ?? '-'}</Typography>
      ),
    },
    {
      key: 'orderType',
      title: translate('text_1775747115932x8ryaymh8ej'),
      minWidth: 220,
      content: ({ orderType }) => (
        <Typography color="grey600">
          {translate(getQuoteOrderTypeTranslationKey(orderType))}
        </Typography>
      ),
    },
    getCreatedAtColumn<QuoteListItemFragment>('text_624efab67eb2570101d117e3', 160),
  ]
}
