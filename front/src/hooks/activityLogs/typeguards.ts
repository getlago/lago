import { ResourceTypeEnum } from '~/generated/graphql'

export type EmailActivity = {
  document: {
    lago_id: string
    number: string
    type: ResourceTypeEnum
  }
}

export const isEmailActivity = (
  activityObject: Record<string, unknown>,
): activityObject is EmailActivity => {
  return (
    'document' in activityObject &&
    typeof activityObject.document === 'object' &&
    activityObject.document !== null &&
    'lago_id' in activityObject.document &&
    typeof activityObject.document.lago_id === 'string' &&
    'number' in activityObject.document &&
    typeof activityObject.document.number === 'string' &&
    'type' in activityObject.document &&
    typeof activityObject.document.type === 'string'
  )
}
