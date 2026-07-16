import { useEffect, useMemo } from 'react'
import { generatePath } from 'react-router-dom'

import { MainHeader } from '~/components/MainHeader/MainHeader'
import { useMainHeaderTabContent } from '~/components/MainHeader/useMainHeaderTabContent'
import { NewAnalyticsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  ANALYTIC_ROUTE,
  ANALYTIC_TABS_ROUTE,
  ANALYTICS_V2_ROUTE,
  ANALYTICS_V2_TABS_ROUTE,
  useLocation,
  useNavigate,
} from '~/core/router'
import { PremiumIntegrationTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import Invoices from '~/pages/analytics/Invoices'
import Mrr from '~/pages/analytics/Mrr'
import PrepaidCredits from '~/pages/analytics/PrepaidCredits'
import RevenueStreams from '~/pages/analytics/RevenueStreams'
import Usage from '~/pages/analytics/Usage'

const NewAnalytics = () => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { pathname } = useLocation()
  const { hasOrganizationPremiumAddon } = useOrganizationInfos()

  const hasAccessToUsage = hasOrganizationPremiumAddon(PremiumIntegrationTypeEnum.RevenueAnalytics)

  // Determine which route family we're in based on current pathname
  const isV2Route = pathname.startsWith('/analytics-v2')
  const baseRoute = isV2Route ? ANALYTICS_V2_ROUTE : ANALYTIC_ROUTE
  const baseTabsRoute = isV2Route ? ANALYTICS_V2_TABS_ROUTE : ANALYTIC_TABS_ROUTE

  // Redirect to revenue-streams when URL is exactly /analytics or /analytics-v2
  // Cause we support old and new analytics routes, this is needed
  useEffect(() => {
    if (pathname === ANALYTICS_V2_ROUTE || pathname === ANALYTIC_ROUTE) {
      navigate(
        generatePath(baseTabsRoute, {
          tab: NewAnalyticsTabsOptionsEnum.revenueStreams,
        }),
        { replace: true },
      )
    }
  }, [pathname, navigate, baseTabsRoute])

  const tabs = useMemo(
    () => [
      {
        title: translate('text_1739203651003n5f5qzxnhin'),
        link: generatePath(baseTabsRoute, {
          tab: NewAnalyticsTabsOptionsEnum.revenueStreams,
        }),
        match: [
          baseRoute,
          generatePath(baseRoute),
          generatePath(baseTabsRoute, {
            tab: NewAnalyticsTabsOptionsEnum.revenueStreams,
          }),
        ],
        content: <RevenueStreams />,
      },
      {
        title: translate('text_6553885df387fd0097fd738c'),
        link: generatePath(baseTabsRoute, {
          tab: NewAnalyticsTabsOptionsEnum.mrr,
        }),
        content: <Mrr />,
      },
      {
        title: translate('text_17465414264635ktqocy7leo'),
        link: generatePath(baseTabsRoute, {
          tab: NewAnalyticsTabsOptionsEnum.usage,
        }),
        hidden: !hasAccessToUsage,
        content: <Usage />,
      },
      {
        title: translate('text_1744192691931osnm4ckcvzj'),
        link: generatePath(baseTabsRoute, {
          tab: NewAnalyticsTabsOptionsEnum.prepaidCredits,
        }),
        content: <PrepaidCredits />,
      },
      {
        title: translate('text_1745933666707rlg89cuv1i0'),
        link: generatePath(baseTabsRoute, {
          tab: NewAnalyticsTabsOptionsEnum.invoices,
        }),
        content: <Invoices />,
      },
    ],
    [translate, hasAccessToUsage, baseRoute, baseTabsRoute],
  )

  const activeTabContent = useMainHeaderTabContent()

  return (
    <>
      <MainHeader.Configure
        entity={{
          viewName: translate('text_6553885df387fd0097fd7384'),
        }}
        tabs={tabs}
      />

      {activeTabContent}
    </>
  )
}

export default NewAnalytics
