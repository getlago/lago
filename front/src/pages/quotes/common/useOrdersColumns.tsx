import { generatePath } from 'react-router-dom'

import { Status } from '~/components/designSystem/Status'
import { TableColumn } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { QuoteDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { Link, QUOTE_DETAILS_ROUTE } from '~/core/router'
import { OrderListItemFragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

import { getOrderExecutionModeTranslationKey } from './getOrderExecutionModeTranslationKey'
import { getOrderStatusMapping } from './getOrderStatusMapping'

export const useOrdersColumns = ({
  hideSourceQuote,
}: {
  hideSourceQuote: boolean
}): Array<TableColumn<OrderListItemFragment>> => {
  const { translate } = useInternationalization()
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()

  const sourceQuoteColumn: TableColumn<OrderListItemFragment> = {
    key: 'orderForm.quote.number',
    title: translate('text_1779695273381h7tmhdzrv48'),
    minWidth: 160,
    content: ({ orderForm }) => (
      <Typography color="info600" noWrap>
        <Link
          to={generatePath(QUOTE_DETAILS_ROUTE, {
            quoteId: orderForm.quote.id,
            tab: QuoteDetailsTabsOptionsEnum.overview,
          })}
        >
          {orderForm.quote.number}
        </Link>
      </Typography>
    ),
  }

  return [
    {
      key: 'number',
      title: translate('text_1782392058759pmmuy0h997w'),
      minWidth: 160,
      maxSpace: true,
      content: ({ number }) => (
        <Typography variant="bodyHl" noWrap>
          {number}
        </Typography>
      ),
    },
    {
      key: 'status',
      title: translate('text_63ac86d797f728a87b2f9fa7'),
      minWidth: 100,
      content: ({ status }) => <Status {...getOrderStatusMapping(status, translate)} />,
    },
    ...(hideSourceQuote ? [] : [sourceQuoteColumn]),
    {
      key: 'orderForm.number',
      title: translate('text_1782392058759f99av1go7r6'),
      minWidth: 160,
      content: ({ orderForm }) => (
        <Typography color="info600" noWrap>
          <Link
            to={generatePath(QUOTE_DETAILS_ROUTE, {
              quoteId: orderForm.quote.id,
              tab: QuoteDetailsTabsOptionsEnum.orderForms,
            })}
          >
            {orderForm.number}
          </Link>
        </Typography>
      ),
    },
    {
      key: 'executionMode',
      title: translate('text_17823920587599ha9n3uhfuj'),
      minWidth: 140,
      content: ({ executionMode }) => {
        const key = getOrderExecutionModeTranslationKey(executionMode)

        return (
          <Typography color="grey600" noWrap>
            {key ? translate(key) : '-'}
          </Typography>
        )
      },
    },
    {
      key: 'executedAt',
      title: translate('text_1782392058759njezxv1yrhl'),
      minWidth: 120,
      content: ({ executedAt }) => (
        <Typography color="grey600">
          {executedAt ? intlFormatDateTimeOrgaTZ(executedAt).date : '-'}
        </Typography>
      ),
    },
  ]
}
