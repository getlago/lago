import type { RouteObject } from 'react-router-dom'

import { FeatureFlagEnum } from '~/generated/graphql'
import { TMembershipPermissions } from '~/hooks/usePermissions'

export interface CustomRouteObject extends Omit<RouteObject, 'children' | 'path'> {
  path?: string | string[]
  private?: boolean
  onlyPublic?: boolean
  invitation?: boolean
  redirect?: string
  children?: CustomRouteObject[]
  permissions?: Array<keyof TMembershipPermissions> // AND logic (all must be true)
  permissionsOr?: Array<keyof TMembershipPermissions> // OR logic (at least one must be true)
  featureFlag?: FeatureFlagEnum
}
