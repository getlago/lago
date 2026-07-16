import { useEffect, useMemo } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import {
  Filters,
  OrderAvailableFilters,
  OrderFormAvailableFilters,
  QuoteAvailableFilters,
} from '~/components/designSystem/Filters'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { useMainHeaderTabContent } from '~/components/MainHeader/useMainHeaderTabContent'
import PremiumFeature from '~/components/premium/PremiumFeature'
import {
  ORDER_FORM_LIST_FILTER_PREFIX,
  ORDER_LIST_FILTER_PREFIX,
  QUOTE_LIST_FILTER_PREFIX,
} from '~/core/constants/filters'
import { QuotesTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  CREATE_QUOTE_ROUTE,
  QUOTES_LIST_ROUTE,
  QUOTES_TAB_ROUTE,
  useLocation,
  useNavigate,
} from '~/core/router'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { usePermissions } from '~/hooks/usePermissions'

import OrderFormsList from './OrderFormsList'
import OrdersList from './OrdersList'
import QuotesList from './QuotesList'

export const CREATE_QUOTE_BUTTON_TEST_ID = 'create-quote-button'

const Quotes = (): JSX.Element => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { pathname } = useLocation()
  const { hasPermissions } = usePermissions()
  const canCreateQuotes = hasPermissions(['quotesCreate'])
  const canViewOrderForms = hasPermissions(['orderFormsView'])
  const { isPremium } = useCurrentUser()
  const { tab } = useParams()
  const tabFilterConfig: Record<
    QuotesTabsOptionsEnum,
    {
      filtersNamePrefix: string
      availableFilters: typeof QuoteAvailableFilters
      snapshotKey: string
    }
  > = {
    [QuotesTabsOptionsEnum.quotes]: {
      filtersNamePrefix: QUOTE_LIST_FILTER_PREFIX,
      availableFilters: QuoteAvailableFilters,
      snapshotKey: 'quotes',
    },
    [QuotesTabsOptionsEnum.orderForms]: {
      filtersNamePrefix: ORDER_FORM_LIST_FILTER_PREFIX,
      availableFilters: OrderFormAvailableFilters,
      snapshotKey: 'order-forms',
    },
    [QuotesTabsOptionsEnum.orders]: {
      filtersNamePrefix: ORDER_LIST_FILTER_PREFIX,
      availableFilters: OrderAvailableFilters,
      snapshotKey: 'orders',
    },
  }

  const filterConfig =
    tabFilterConfig[tab as QuotesTabsOptionsEnum] ?? tabFilterConfig[QuotesTabsOptionsEnum.quotes]

  useEffect(() => {
    if (pathname === QUOTES_LIST_ROUTE) {
      navigate(
        generatePath(QUOTES_TAB_ROUTE, {
          tab: QuotesTabsOptionsEnum.quotes,
        }),
        { replace: true },
      )
    }
  }, [pathname, navigate])

  const tabs = useMemo(
    () => [
      {
        title: translate('text_17757391860814p20fr87x9g'),
        link: generatePath(QUOTES_TAB_ROUTE, {
          tab: QuotesTabsOptionsEnum.quotes,
        }),
        match: [
          QUOTES_LIST_ROUTE,
          generatePath(QUOTES_TAB_ROUTE, {
            tab: QuotesTabsOptionsEnum.quotes,
          }),
        ],
        content: <QuotesList />,
      },
      ...(canViewOrderForms
        ? [
            {
              title: translate('text_17757461968258p4ij8g74zp'),
              link: generatePath(QUOTES_TAB_ROUTE, {
                tab: QuotesTabsOptionsEnum.orderForms,
              }),
              content: <OrderFormsList />,
            },
          ]
        : []),
      {
        title: translate('text_17823920587596x5e6nes7qv'),
        link: generatePath(QUOTES_TAB_ROUTE, {
          tab: QuotesTabsOptionsEnum.orders,
        }),
        content: <OrdersList />,
      },
    ],
    [translate, canViewOrderForms],
  )

  const activeTabContent = useMainHeaderTabContent()

  return (
    <>
      <MainHeader.Configure
        entity={{
          viewName: translate('text_17757391860814p20fr87x9g'),
        }}
        {...(isPremium
          ? {
              tabs,
              // The filtersSection is tab-dependent but stripped from the config snapshot
              // (it's a ReactNode). Bump snapshotKey per tab so switching tabs re-pushes the
              // matching filter panel instead of leaving the previous tab's panel in context.
              snapshotKey: filterConfig.snapshotKey,
              actions: {
                items: [
                  {
                    type: 'action',
                    label: translate('text_1776238919927a1b2c3d4e5f'),
                    variant: 'primary',
                    hidden: !canCreateQuotes,
                    onClick: () => navigate(CREATE_QUOTE_ROUTE),
                    dataTest: CREATE_QUOTE_BUTTON_TEST_ID,
                  },
                ],
              },
              filtersSection: (
                <div className="pt-4">
                  <Filters.Provider
                    key={filterConfig.snapshotKey}
                    filtersNamePrefix={filterConfig.filtersNamePrefix}
                    availableFilters={filterConfig.availableFilters}
                  >
                    <Filters.Component />
                  </Filters.Provider>
                </div>
              ),
            }
          : {})}
      />

      {isPremium && activeTabContent}

      {!isPremium && (
        <DetailsPage.Container>
          <PremiumFeature
            data-test="quotes-premium-feature"
            title={translate('text_17767737688593usnzzqqy7f')}
            description={translate('text_1776773768859lvcuax763ex')}
            feature={translate('text_17757391860814p20fr87x9g')}
          />
        </DetailsPage.Container>
      )}
    </>
  )
}

export default Quotes
