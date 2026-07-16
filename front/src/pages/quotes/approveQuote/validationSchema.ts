import { DateTime } from 'luxon'
import { z } from 'zod'

import { ApproveQuoteVersionInput } from '~/generated/graphql'

export const approveQuoteValidationSchema = z.object({
  expiresAt: z.string().optional(),
})

export type ApproveQuoteFormValues = z.infer<typeof approveQuoteValidationSchema>

export const approveQuoteDefaultValues: ApproveQuoteFormValues = {
  expiresAt: undefined,
}

export const buildApproveQuoteVersionInput = (
  versionId: string,
  values: ApproveQuoteFormValues,
): ApproveQuoteVersionInput => ({
  id: versionId,
  expiresAt: values.expiresAt
    ? (DateTime.fromISO(values.expiresAt, { zone: 'utc' }).endOf('day').toISO() ?? undefined)
    : undefined,
})
