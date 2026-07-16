import { useEffect } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { MainHeader } from '~/components/MainHeader/MainHeader'
import { MainHeaderAction } from '~/components/MainHeader/types'
import { useMainHeaderTabContent } from '~/components/MainHeader/useMainHeaderTabContent'
import { QuoteDetailsTabsOptionsEnum, QuotesTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  QUOTE_DETAILS_ROUTE,
  QUOTES_LIST_ROUTE,
  QUOTES_TAB_ROUTE,
  useNavigate,
} from '~/core/router'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'

import { useQuote } from './hooks/useQuote'
import { useQuoteVersionActions } from './hooks/useQuoteVersionActions'
import OrderFormsList from './OrderFormsList'
import OrdersList from './OrdersList'
import QuoteDetailsVersions from './QuoteDetailsVersions'

const QuoteDetails = (): JSX.Element => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { quoteId } = useParams()
  const { quote, loading } = useQuote(quoteId)
  const { getActions } = useQuoteVersionActions()
  const { hasPermissions } = usePermissions()
  const canViewOrderForms = hasPermissions(['orderFormsView'])

  useEffect(() => {
    if (loading || quote) return

    navigate(QUOTES_LIST_ROUTE, { replace: true })
  }, [loading, quote, navigate])

  const activeTabContent = useMainHeaderTabContent()

  const headerActions: MainHeaderAction[] = (() => {
    if (!quote) return []

    const actions = getActions(quote)

    if (actions.length === 0) return []

    return [
      {
        type: 'dropdown' as const,
        label: translate('text_1776414006125pcxcyeblul7'),
        items: actions.map(({ icon, label, onAction }) => ({
          label,
          startIcon: icon,
          onClick: (closePopper: () => void) => {
            onAction()
            closePopper()
          },
        })),
      },
    ]
  })()

  return (
    <>
      <MainHeader.Configure
        breadcrumb={[
          {
            label: translate('text_17757391860814p20fr87x9g'),
            path: generatePath(QUOTES_TAB_ROUTE, {
              tab: QuotesTabsOptionsEnum.quotes,
            }),
          },
        ]}
        entity={{
          viewName: quote?.number ?? '',
          viewNameLoading: loading,
          metadata: quote ? `${quote.customer.displayName} - ${quote.customer.externalId}` : '',
          metadataLoading: loading,
        }}
        actions={{ items: headerActions, loading }}
        tabs={[
          {
            title: translate('text_17758226782042kygnyzs2nh'),
            link: generatePath(QUOTE_DETAILS_ROUTE, {
              quoteId: quoteId as string,
              tab: QuoteDetailsTabsOptionsEnum.overview,
            }),
            content: quote ? <QuoteDetailsVersions quote={quote} /> : null,
          },
          ...(canViewOrderForms
            ? [
                {
                  title: translate('text_17757461968258p4ij8g74zp'),
                  link: generatePath(QUOTE_DETAILS_ROUTE, {
                    quoteId: quoteId as string,
                    tab: QuoteDetailsTabsOptionsEnum.orderForms,
                  }),
                  content: <OrderFormsList quoteNumber={quote?.number} />,
                },
              ]
            : []),
          {
            title: translate('text_17823920587596x5e6nes7qv'),
            link: generatePath(QUOTE_DETAILS_ROUTE, {
              quoteId: quoteId as string,
              tab: QuoteDetailsTabsOptionsEnum.orders,
            }),
            content: <OrdersList quoteNumber={quote?.number} />,
          },
        ]}
      />

      <>{activeTabContent}</>
    </>
  )
}

export default QuoteDetails
