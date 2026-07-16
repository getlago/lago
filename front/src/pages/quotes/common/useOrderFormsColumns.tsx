import { generatePath } from 'react-router-dom'

import { Status } from '~/components/designSystem/Status'
import { TableColumn } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { QuoteDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { Link, QUOTE_DETAILS_ROUTE } from '~/core/router'
import { OrderFormListItemFragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { getOrderFormStatusMapping } from './getOrderFormStatusMapping'
import { useSharedColumns } from './sharedColumns'

export const useOrderFormsColumns = (): Array<TableColumn<OrderFormListItemFragment>> => {
  const { translate } = useInternationalization()
  const { getNumberColumn, getCustomerColumn, getCreatedAtColumn } = useSharedColumns()

  return [
    // "Order form number" — corrects the previous "Quote number" mislabel
    getNumberColumn<OrderFormListItemFragment>('text_1781624189693d7zcv2vog4c'),
    getCustomerColumn<OrderFormListItemFragment>(),
    {
      key: 'status',
      title: translate('text_63ac86d797f728a87b2f9fa7'),
      minWidth: 100,
      content: ({ status }) => <Status {...getOrderFormStatusMapping(status, translate)} />,
    },
    {
      key: 'quote.number',
      title: translate('text_1779695273381h7tmhdzrv48'),
      minWidth: 160,
      content: ({ quote }) => (
        <Typography color="info600" noWrap>
          <Link
            to={generatePath(QUOTE_DETAILS_ROUTE, {
              quoteId: quote.id,
              tab: QuoteDetailsTabsOptionsEnum.overview,
            })}
          >
            {quote.number} - v{quote.currentVersion.version}
          </Link>
        </Typography>
      ),
    },
    getCreatedAtColumn<OrderFormListItemFragment>('text_624efab67eb2570101d117e3', 120),
  ]
}
