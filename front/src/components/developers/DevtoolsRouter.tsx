import { useRoutes } from 'react-router-dom'

import {
  ACTIVITY_LOG_ROUTE,
  ACTIVITY_ROUTE,
  API_KEYS_ROUTE,
  API_LOG_ROUTE,
  API_LOGS_ROUTE,
  EVENT_LOG_ROUTE,
  EVENTS_ROUTE,
  WEBHOOK_LOGS_ROUTE,
  WEBHOOK_ROUTE,
  WEBHOOKS_ROUTE,
} from '~/components/developers/devtoolsRoutes'
import {
  ActivityLogs,
  ApiKeys,
  ApiLogs,
  Events,
  WebhookDetail,
  Webhooks,
} from '~/components/developers/views'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'

export const DevtoolsRouter = () => {
  const routes = useRoutes([
    { path: API_KEYS_ROUTE, element: <ApiKeys /> },

    {
      path: WEBHOOKS_ROUTE,
      element: <Webhooks />,
    },
    { path: WEBHOOK_ROUTE, element: <WebhookDetail /> },
    { path: WEBHOOK_LOGS_ROUTE, element: <WebhookDetail /> },

    { path: EVENTS_ROUTE, element: <Events /> },
    { path: EVENT_LOG_ROUTE, element: <Events /> },

    { path: API_LOGS_ROUTE, element: <ApiLogs /> },
    { path: API_LOG_ROUTE, element: <ApiLogs /> },

    { path: ACTIVITY_ROUTE, element: <ActivityLogs /> },
    { path: ACTIVITY_LOG_ROUTE, element: <ActivityLogs /> },

    { path: '*', element: <ApiKeys /> },
  ])

  return routes
}

export const devToolsNavigationMapping = (
  translate: ReturnType<typeof useInternationalization>['translate'],
  hasPermissions: ReturnType<typeof usePermissions>['hasPermissions'],
  isPremium: boolean,
) => {
  const tabs = [
    {
      title: translate('text_636df520279a9e1b3c68cc67'),
      link: API_KEYS_ROUTE,
      hidden: !hasPermissions(['developersKeysManage']),
    },
    {
      title: translate('text_6271200984178801ba8bdede'),
      link: WEBHOOKS_ROUTE,
      match: [WEBHOOKS_ROUTE, WEBHOOK_ROUTE, WEBHOOK_LOGS_ROUTE],
      hidden: !hasPermissions(['developersManage']),
    },
    {
      title: translate('text_6298bd525e359200d5ea0020'),
      link: EVENTS_ROUTE,
      match: [EVENTS_ROUTE, EVENT_LOG_ROUTE],
      hidden: !hasPermissions(['developersManage']),
    },
    {
      title: translate('text_1749644023729atl2vw7ad3z'),
      link: API_LOGS_ROUTE,
      match: [API_LOGS_ROUTE, API_LOG_ROUTE],
      hidden: !isPremium || !hasPermissions(['developersManage', 'auditLogsView']),
    },
    {
      title: translate('text_1747314141347qq6rasuxisl'),
      link: ACTIVITY_ROUTE,
      match: [ACTIVITY_ROUTE, ACTIVITY_LOG_ROUTE],
      hidden: !isPremium || !hasPermissions(['developersManage', 'auditLogsView']),
    },
  ]

  return tabs
}
