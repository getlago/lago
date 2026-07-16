import { StatusProps, StatusType } from '~/components/designSystem/Status'
import { WebhookStatusEnum } from '~/generated/graphql'

export const statusWebhookMapping = (status?: WebhookStatusEnum | null): StatusProps => {
  switch (status) {
    case WebhookStatusEnum.Pending:
      return {
        type: StatusType.default,
        label: 'pending',
      }
    case WebhookStatusEnum.Failed:
      return {
        type: StatusType.danger,
        label: 'failed',
      }
    case WebhookStatusEnum.Succeeded:
      return {
        type: StatusType.success,
        label: 'delivered',
      }
    default:
      return {
        type: StatusType.default,
        label: 'pending',
      }
  }
}

export const formatWebhookResponseLabel = (
  httpStatus: string | number | null | undefined,
  status: WebhookStatusEnum | null | undefined,
): string => {
  const label = String(statusWebhookMapping(status).label)

  return `${httpStatus} ${label.charAt(0).toUpperCase() + label.slice(1)}`
}
