import {
  customerPortalChildrenRoutes,
  customerPortalRoutes,
} from '~/core/router/CustomerPortalRoutes'
import { customerObjectCreationRoutes, customerVoidRoutes } from '~/core/router/CustomerRoutes'
import { ERROR_404_ROUTE, FORBIDDEN_ROUTE } from '~/core/router/index'
import { objectCreationRoutes } from '~/core/router/ObjectsRoutes'
import { quotesModificationRoutes } from '~/core/router/QuotesRoutes'
import { settingsObjectCreationRoutes } from '~/core/router/SettingRoutes'

/**
 * Transforms route definitions into an array of path objects for route matching.
 * Combines object creation routes, customer creation routes, customer void routes,
 * customer portal routes and error routes into a flat array of path objects that can be used with react-router's matchRoutes.
 * This is used to determine when the AI Agent component should be hidden.
 */
export const getHiddenAiAgentPaths = (): Array<{ path: string }> => {
  const routePaths = [
    ...objectCreationRoutes,
    ...customerObjectCreationRoutes,
    ...customerVoidRoutes,
    ...settingsObjectCreationRoutes,
    ...customerPortalRoutes,
    ...customerPortalChildrenRoutes,
    ...quotesModificationRoutes,
  ]
    ?.reduce((prev, curr) => prev.concat(curr.path ? curr.path : []), [] as string[])
    ?.map((path: string) => ({ path }))

  return [...routePaths, { path: ERROR_404_ROUTE }, { path: FORBIDDEN_ROUTE }]
}
