export const DEVTOOL_ROUTE = '/devtool'

export const API_KEYS_ROUTE = `${DEVTOOL_ROUTE}`

export const WEBHOOKS_ROUTE = `${DEVTOOL_ROUTE}/webhooks`
export const WEBHOOK_ROUTE = `${DEVTOOL_ROUTE}/webhooks/:webhookId`
export const WEBHOOK_LOGS_ROUTE = `${DEVTOOL_ROUTE}/webhooks/:webhookId/logs/:logId`

export const EVENTS_ROUTE = `${DEVTOOL_ROUTE}/events`
export const EVENT_LOG_ROUTE = `${DEVTOOL_ROUTE}/events/*`

export const API_LOGS_ROUTE = `${DEVTOOL_ROUTE}/api-logs`
export const API_LOG_ROUTE = `${DEVTOOL_ROUTE}/api-logs/:logId`

export const ACTIVITY_ROUTE = `${DEVTOOL_ROUTE}/activity-logs`
export const ACTIVITY_LOG_ROUTE = `${DEVTOOL_ROUTE}/activity-logs/:logId`
