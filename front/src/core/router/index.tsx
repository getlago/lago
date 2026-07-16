import { envGlobalVar } from '~/core/apolloClient'
import { AppEnvEnum } from '~/core/constants/globalTypes'

import { authRoutes } from './AuthRoutes'
import { customerPortalRoutes } from './CustomerPortalRoutes'
import { customerObjectCreationRoutes, customerRoutes, customerVoidRoutes } from './CustomerRoutes'
import { objectCreationRoutes, objectDetailsRoutes, objectListRoutes } from './ObjectsRoutes'
import {
  orderFormsModificationRoutes,
  ordersModificationRoutes,
  quotesModificationRoutes,
  quotesRoutes,
} from './QuotesRoutes'
import { settingRoutes } from './SettingRoutes'
import { CustomRouteObject } from './types'
import { lazyLoad } from './utils'
import { makeRelative } from './utils/makeRelative'

const { appEnv } = envGlobalVar()

// ----------- Layouts -----------
const SideNavLayout = lazyLoad(() => import('~/layouts/MainNavLayout/MainNavLayout'))
const OrganizationLayout = lazyLoad(() => import('~/layouts/OrganizationLayout'))

// ----------- Pages -----------
const Home = lazyLoad(() => import('~/pages/home/Home'))
const RootRedirect = lazyLoad(() => import('~/pages/home/RootRedirect'))
const Error404 = lazyLoad(() => import('~/pages/Error404'))
const Error404InApp = lazyLoad(() => import('~/pages/Error404InApp'))
const Forbidden = lazyLoad(() => import('~/pages/Forbidden'))
const Analytic = lazyLoad(() => import('~/pages/Analytics'))
const AnalyticsV2 = lazyLoad(() => import('~/pages/AnalyticsV2'))
const Forecasts = lazyLoad(() => import('~/pages/forecasts/Forecasts'))
const UsageBillableMetric = lazyLoad(() => import('~/pages/analytics/UsageBillableMetric'))

// Route Available only on dev mode
const DesignSystem = lazyLoad(() => import('~/pages/__devOnly/DesignSystem'))

export const HOME_ROUTE = '/'
export const FORBIDDEN_ROUTE = '/forbidden'
export const ANALYTIC_ROUTE = '/analytics'
export const ANALYTICS_V2_ROUTE = '/analytics-v2'
export const ANALYTIC_TABS_ROUTE = '/analytics/:tab'
export const ANALYTICS_V2_TABS_ROUTE = '/analytics-v2/:tab'
export const ANALYTIC_USAGE_BILLABLE_METRIC_ROUTE = '/analytics/usage/:billableMetricCode'
export const FORECASTS_ROUTE = '/forecasts'
export const ERROR_404_ROUTE = '/404'

// Route Available only on dev mode
export const ONLY_DEV_DESIGN_SYSTEM_ROUTE = `/design-system`
export const ONLY_DEV_DESIGN_SYSTEM_TAB_ROUTE = `${ONLY_DEV_DESIGN_SYSTEM_ROUTE}/:tab`

const analyticsInlineRoutes: CustomRouteObject[] = [
  {
    path: [ANALYTIC_ROUTE, ANALYTIC_TABS_ROUTE],
    private: true,
    element: <Analytic />,
    // IMPORTANT: This is not 100% correct but can be fixed later.
    // Those 2 permissions are not the same and refer to the old and new analytics access, but are defined with the same restrictions per role
    // To preserve cached last visited route and prevent broken redirection I prefer to keepboth in the same place and not fix this now.
    // Maybe analyticsView will be removed in the future
    permissions: ['analyticsView', 'dataApiView'],
  },
  {
    path: [ANALYTICS_V2_ROUTE, ANALYTICS_V2_TABS_ROUTE],
    private: true,
    element: <AnalyticsV2 />,
    // IMPORTANT: This is not 100% correct but can be fixed later.
    // Those 2 permissions are not the same and refer to the old and new analytics access, but are defined with the same restrictions per role
    // To preserve cached last visited route and prevent broken redirection I prefer to keepboth in the same place and not fix this now.
    // Maybe analyticsView will be removed in the future
    permissions: ['analyticsView', 'dataApiView'],
  },
  {
    path: ANALYTIC_USAGE_BILLABLE_METRIC_ROUTE,
    private: true,
    element: <UsageBillableMetric />,
    permissions: ['analyticsView', 'dataApiView'],
  },
  {
    path: FORECASTS_ROUTE,
    private: true,
    element: <Forecasts />,
    permissions: ['analyticsView', 'dataApiView'],
  },
]

const devOnlyInlineRoutes: CustomRouteObject[] = [AppEnvEnum.qa, AppEnvEnum.development].includes(
  appEnv,
)
  ? [
      {
        path: [ONLY_DEV_DESIGN_SYSTEM_ROUTE, ONLY_DEV_DESIGN_SYSTEM_TAB_ROUTE],
        element: <DesignSystem />,
      },
    ]
  : []

export const routes: CustomRouteObject[] = [
  {
    path: '*',
    element: <Error404 />,
  },
  {
    path: ERROR_404_ROUTE,
    element: <Error404 />,
  },
  {
    path: FORBIDDEN_ROUTE,
    element: <Forbidden />,
  },
  {
    // Root redirect hub — lives OUTSIDE :organizationSlug, where there is no
    // org context yet. `RootRedirect` only resolves WHICH org to enter
    // (saved `from` slug → SSO redirect slug → persisted last-used slug →
    // first accessible membership) and navigates to `/${slug}/`. The
    // permission-based landing-PAGE decision happens afterwards in `Home`, at
    // the `/:organizationSlug` index, where the org context is available.
    path: HOME_ROUTE,
    element: <RootRedirect />,
    private: true,
  },
  {
    path: ':organizationSlug',
    element: <OrganizationLayout />,
    private: true,
    children: [
      {
        element: <SideNavLayout />,
        children: [
          {
            index: true,
            element: <Home />,
          },
          ...makeRelative(analyticsInlineRoutes),
          ...makeRelative(customerRoutes),
          ...makeRelative(objectListRoutes),
          ...makeRelative(objectDetailsRoutes),
          ...makeRelative(quotesRoutes),
          ...makeRelative(devOnlyInlineRoutes),
          {
            path: '*',
            element: <Error404InApp />,
          },
        ],
      },
      ...makeRelative(settingRoutes),
      ...makeRelative(customerObjectCreationRoutes),
      ...makeRelative(customerVoidRoutes),
      ...makeRelative(objectCreationRoutes),
      ...makeRelative(quotesModificationRoutes),
      ...makeRelative(orderFormsModificationRoutes),
      ...makeRelative(ordersModificationRoutes),
    ],
  },
  ...authRoutes,
  ...customerPortalRoutes,
]

export * from './AuthRoutes'
export * from './CustomerRoutes'
export * from './ObjectsRoutes'
export * from './QuotesRoutes'
export * from './SettingRoutes'
export * from './types'

// Slug-aware wrappers — use these over `react-router-dom` at call sites so
// the org slug is auto-prepended and, in any case, took into account.
// Enforced by the ESLint `no-restricted-imports` in  packages/configs/eslint.config.mjs
export { Link } from './Link'
export { useLocation } from './useLocation'
export type { SlugAwareLocation } from './useLocation'
export { useNavigate } from './useNavigate'
