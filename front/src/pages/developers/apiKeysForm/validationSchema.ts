import { z } from 'zod'

import { ApiKeysPermissionsEnum } from '~/generated/graphql'

const apiKeyPermissionSchema = z.object({
  id: z.enum(ApiKeysPermissionsEnum),
  canRead: z.boolean(),
  canWrite: z.boolean(),
})

export const apiKeysFormValidationSchema = z.object({
  name: z.string(),
  permissions: z.array(apiKeyPermissionSchema),
})

export type ApiKeyPermissions = z.infer<typeof apiKeyPermissionSchema>
