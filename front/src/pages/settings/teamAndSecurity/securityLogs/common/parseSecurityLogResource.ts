import { captureException } from '@sentry/react'
import { z } from 'zod'

import { SecurityLogWithId } from './securityLogsTypes'

// Sentry dedupes on fingerprint but we also gate locally so the same drift
// doesn't re-capture for every row rendered in a page of security logs.
const reportedDrifts = new Set<string>()

/**
 * Runs `schema` against `securityLog.resources`. On failure, reports a drift
 * to Sentry once per logEvent per session and returns null so the caller can
 * fall back to an "unknown" rendering. This is the only guard against the
 * backend (which serializes `resources` as the GraphQL `JSON` scalar)
 * silently changing shape — as happened in ISSUE-1833, where `roles.added`
 * moved from string to string[] and every role_edited entry rendered as
 * "unknown" for weeks before a customer reported it.
 */
export const parseSecurityLogResource = <T>(
  schema: z.ZodType<T>,
  securityLog: SecurityLogWithId,
): T | null => {
  const parsed = schema.safeParse(securityLog.resources)

  if (parsed.success) return parsed.data

  if (!reportedDrifts.has(securityLog.logEvent)) {
    reportedDrifts.add(securityLog.logEvent)
    captureException(new Error(`Security log resource shape drifted for ${securityLog.logEvent}`), {
      tags: {
        feature: 'security_logs',
        logEvent: securityLog.logEvent,
      },
      extra: {
        logId: securityLog.logId,
        resources: securityLog.resources,
        zodIssues: parsed.error.issues,
      },
    })
  }

  return null
}

// Exposed for tests only — lets a test reset the in-memory dedupe set so it
// can exercise the "reports once" behavior in isolation.
export const __resetDriftReportingForTests = () => {
  reportedDrifts.clear()
}
