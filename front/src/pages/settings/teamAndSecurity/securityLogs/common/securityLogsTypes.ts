import { z } from 'zod'

import { GetSecurityLogsQuery } from '~/generated/graphql'

export type SecurityLogs = NonNullable<GetSecurityLogsQuery['securityLogs']>['collection']
type SecurityLog = SecurityLogs[number]

export type SecurityLogWithId = SecurityLog & { id: string }

// `SecurityLog.resources` is typed as the GraphQL `JSON` scalar, so codegen
// gives us `any`. These schemas are the only contract that matches the payload
// each backend service serializes. If the backend shape drifts, safeParse
// returns a failure and the UI falls back to the "unknown" branch loudly
// instead of silently accessing undefined fields.

export const apiKeyResourceSchema = z.object({
  name: z.string(),
  value_ending: z.union([z.string(), z.number()]),
})
export const rotatedApiKeyResourceSchema = z.object({
  name: z.string(),
  value_ending: z.object({
    deleted: z.string(),
    added: z.string(),
  }),
})

export const billingEntityResourceSchema = z.object({
  billing_entity_name: z.string(),
})

export const integrationResourceSchema = z.object({
  integration_name: z.string(),
})

export const roleResourceSchema = z.object({
  role_code: z.string(),
})

export const inviteResourceSchema = z.object({
  invitee_email: z.string(),
})

// Backend (`Memberships::UpdateService#register_security_log`) sends
// `{ added: ['code', ...], deleted: ['code', ...] }`. Either key can be absent
// when the user only gained or only lost roles; the guard requires at least one.
export const roleEditedResourceSchema = z
  .object({
    email: z.string(),
    roles: z.object({
      added: z.array(z.string()).optional(),
      deleted: z.array(z.string()).optional(),
    }),
  })
  .refine(({ roles }) => !!roles.added?.length || !!roles.deleted?.length, {
    message: 'roles.added or roles.deleted must contain at least one code',
  })

export const webhookResourceSchema = z.object({
  webhook_url: z.string(),
})

const stringDiffSchema = z.object({
  deleted: z.string(),
  added: z.string(),
})

export const webhookEditedResourceSchema = z.object({
  webhook_url: z.union([z.string(), stringDiffSchema]),
  signature_algo: stringDiffSchema.optional(),
})
