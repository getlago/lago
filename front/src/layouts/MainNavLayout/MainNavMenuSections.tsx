import { Icon } from 'lago-design-system'

import { VerticalMenu, VerticalMenuSectionTitle } from '~/components/designSystem/VerticalMenu'
import {
  ADD_ON_DETAILS_ROUTE,
  ADD_ONS_ROUTE,
  ANALYTIC_ROUTE,
  ANALYTIC_TABS_ROUTE,
  BILLABLE_METRIC_DETAILS_ROUTE,
  BILLABLE_METRICS_ROUTE,
  COUPON_DETAILS_ROUTE,
  COUPONS_ROUTE,
  CREDIT_NOTES_ROUTE,
  CUSTOMER_CREDIT_NOTE_DETAILS_ROUTE,
  CUSTOMER_DETAILS_ROUTE,
  CUSTOMER_DETAILS_TAB_ROUTE,
  CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE,
  CUSTOMER_INVOICE_DETAILS_ROUTE,
  CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE,
  CUSTOMER_SUBSCRIPTION_PLAN_DETAILS,
  CUSTOMERS_LIST_ROUTE,
  FEATURE_DETAILS_ROUTE,
  FEATURES_ROUTE,
  FORECASTS_ROUTE,
  INVOICES_ROUTE,
  PAYMENT_DETAILS_ROUTE,
  PAYMENTS_ROUTE,
  PLAN_DETAILS_ROUTE,
  PLAN_SUBSCRIPTION_DETAILS_ROUTE,
  PLANS_ROUTE,
  QUOTE_DETAILS_ROUTE,
  QUOTES_LIST_ROUTE,
  QUOTES_TAB_ROUTE,
  SUBSCRIPTIONS_ROUTE,
  WALLET_DETAILS_ROUTE,
} from '~/core/router'
import { FeatureFlagEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissions } from '~/hooks/usePermissions'
import { NavLayout } from '~/layouts/NavLayout'
import { BadgeAI } from '~/pages/forecasts/Forecasts'

import { getNavTabs, NavTab } from './utils'
import { VerticalMenuSkeleton } from './VerticalMenuSkeleton'

export const MAIN_NAV_MENU_SECTIONS_TEST_ID = 'main-nav-menu-sections'
export const MAIN_NAV_REPORTS_SECTION_TEST_ID = 'main-nav-reports-section'
export const MAIN_NAV_CONFIGURATION_SECTION_TEST_ID = 'main-nav-configuration-section'
export const MAIN_NAV_BILLING_SECTION_TEST_ID = 'main-nav-billing-section'

interface MainNavMenuSectionsProps {
  isLoading: boolean
  onItemClick: () => void
}

export const MainNavMenuSections = ({ isLoading, onItemClick }: MainNavMenuSectionsProps) => {
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const { hasFeatureFlag } = useOrganizationInfos()
  const { isPremium } = useCurrentUser()

  const getReportsTabs = (): NavTab[] => [
    {
      title: translate('text_6553885df387fd0097fd7384'),
      icon: 'chart-bar',
      link: ANALYTIC_ROUTE,
      match: [ANALYTIC_ROUTE, ANALYTIC_TABS_ROUTE],
      hidden: !hasPermissions(['analyticsView']),
    },
    {
      title: translate('text_1753014457040hxp6wkphkvw'),
      icon: 'forecast',
      link: FORECASTS_ROUTE,
      match: [FORECASTS_ROUTE],
      hidden: !hasPermissions(['analyticsView']),
      extraComponent: <BadgeAI />,
    },
  ]

  const getConfigurationTabs = (): NavTab[] => [
    {
      title: translate('text_623b497ad05b960101be3448'),
      icon: 'pulse',
      link: BILLABLE_METRICS_ROUTE,
      canBeClickedOnActive: true,
      match: [BILLABLE_METRICS_ROUTE, BILLABLE_METRIC_DETAILS_ROUTE],
      hidden: !hasPermissions(['billableMetricsView']),
    },
    {
      title: translate('text_62442e40cea25600b0b6d85a'),
      icon: 'board',
      link: PLANS_ROUTE,
      canBeClickedOnActive: true,
      match: [PLANS_ROUTE, PLAN_DETAILS_ROUTE, CUSTOMER_SUBSCRIPTION_PLAN_DETAILS],
      hidden: !hasPermissions(['plansView']),
    },
    {
      title: translate('text_1752692673070k7z0mmf0494'),
      icon: 'switch',
      link: FEATURES_ROUTE,
      canBeClickedOnActive: true,
      match: [FEATURES_ROUTE, FEATURE_DETAILS_ROUTE],
      hidden: !hasPermissions(['featuresView']),
    },
    {
      title: translate('text_629728388c4d2300e2d3801a'),
      icon: 'puzzle',
      link: ADD_ONS_ROUTE,
      canBeClickedOnActive: true,
      match: [ADD_ONS_ROUTE, ADD_ON_DETAILS_ROUTE],
      hidden: !hasPermissions(['addonsView']),
    },
    {
      title: translate('text_62865498824cc10126ab2940'),
      icon: 'coupon',
      link: COUPONS_ROUTE,
      canBeClickedOnActive: true,
      match: [COUPONS_ROUTE, COUPON_DETAILS_ROUTE],
      hidden: !hasPermissions(['couponsView']),
    },
  ]

  const getBillingTabs = (): NavTab[] => [
    {
      title: translate('text_624efab67eb2570101d117a5'),
      icon: 'user-multiple',
      link: CUSTOMERS_LIST_ROUTE,
      canBeClickedOnActive: true,
      match: [
        CUSTOMERS_LIST_ROUTE,
        CUSTOMER_DETAILS_ROUTE,
        CUSTOMER_DETAILS_TAB_ROUTE,
        WALLET_DETAILS_ROUTE,
      ],
      hidden: !hasPermissions(['customersView']),
    },
    {
      title: translate('text_17757391860814p20fr87x9g'),
      icon: 'writing-sign',
      link: QUOTES_LIST_ROUTE,
      canBeClickedOnActive: true,
      match: [QUOTES_LIST_ROUTE, QUOTES_TAB_ROUTE, QUOTE_DETAILS_ROUTE],
      hidden: !hasPermissions(['quotesView']) || !hasFeatureFlag(FeatureFlagEnum.OrderForms),
      extraComponent: isPremium ? undefined : (
        <span data-test="quotes-nav-premium-icon">
          <Icon name="sparkles" />
        </span>
      ),
    },
    {
      title: translate('text_6250304370f0f700a8fdc28d'),
      icon: 'clock',
      link: SUBSCRIPTIONS_ROUTE,
      match: [
        SUBSCRIPTIONS_ROUTE,
        CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE,
        PLAN_SUBSCRIPTION_DETAILS_ROUTE,
      ],
      canBeClickedOnActive: true,
      hidden: !hasPermissions(['subscriptionsView']),
    },
    {
      title: translate('text_63ac86d797f728a87b2f9f85'),
      icon: 'document',
      link: INVOICES_ROUTE,
      canBeClickedOnActive: true,
      match: [INVOICES_ROUTE, CUSTOMER_INVOICE_DETAILS_ROUTE],
      hidden: !hasPermissions(['invoicesView']),
    },
    {
      title: translate('text_6672ebb8b1b50be550eccbed'),
      icon: 'coin-dollar',
      link: PAYMENTS_ROUTE,
      match: [PAYMENTS_ROUTE, PAYMENT_DETAILS_ROUTE],
      canBeClickedOnActive: true,
      hidden: !hasPermissions(['paymentsView']),
    },
    {
      title: translate('text_66461ada56a84401188e8c63'),
      icon: 'receipt',
      link: CREDIT_NOTES_ROUTE,
      match: [
        CREDIT_NOTES_ROUTE,
        CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE,
        CUSTOMER_CREDIT_NOTE_DETAILS_ROUTE,
      ],
      canBeClickedOnActive: true,
      hidden: !hasPermissions(['creditNotesView']),
    },
  ]

  const reportsTabs = getNavTabs(getReportsTabs())
  const configurationTabs = getNavTabs(getConfigurationTabs())
  const billingTabs = getNavTabs(getBillingTabs())

  // Don't render the section group if all sections are hidden
  if (reportsTabs.allTabsHidden && configurationTabs.allTabsHidden && billingTabs.allTabsHidden) {
    return null
  }

  return (
    <NavLayout.NavSectionGroup data-test={MAIN_NAV_MENU_SECTIONS_TEST_ID}>
      {/* Reports */}
      {!reportsTabs.allTabsHidden && (
        <NavLayout.NavSection data-test={MAIN_NAV_REPORTS_SECTION_TEST_ID}>
          <VerticalMenuSectionTitle
            title={translate('text_1750864025932bnohjbzci3f')}
            loading={isLoading}
          />
          <VerticalMenu
            loading={isLoading}
            loadingComponent={<VerticalMenuSkeleton numberOfElements={1} />}
            onClick={onItemClick}
            tabs={reportsTabs.tabs}
          />
        </NavLayout.NavSection>
      )}

      {/* Configuration */}
      {!configurationTabs.allTabsHidden && (
        <NavLayout.NavSection data-test={MAIN_NAV_CONFIGURATION_SECTION_TEST_ID}>
          <VerticalMenuSectionTitle
            title={translate('text_1750864088654kxz304zdo2z')}
            loading={isLoading}
          />
          <VerticalMenu
            loading={isLoading}
            loadingComponent={<VerticalMenuSkeleton numberOfElements={5} />}
            onClick={onItemClick}
            tabs={configurationTabs.tabs}
          />
        </NavLayout.NavSection>
      )}

      {/* Billing & operations */}
      {!billingTabs.allTabsHidden && (
        <NavLayout.NavSection data-test={MAIN_NAV_BILLING_SECTION_TEST_ID}>
          <VerticalMenuSectionTitle
            title={translate('text_1750864088654s9qo2h9fvp7')}
            loading={isLoading}
          />
          <VerticalMenu
            loading={isLoading}
            loadingComponent={<VerticalMenuSkeleton numberOfElements={2} />}
            onClick={onItemClick}
            tabs={billingTabs.tabs}
          />
        </NavLayout.NavSection>
      )}
    </NavLayout.NavSectionGroup>
  )
}
