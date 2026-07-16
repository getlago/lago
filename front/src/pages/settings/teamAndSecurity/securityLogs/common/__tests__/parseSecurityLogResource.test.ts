import { captureException } from '@sentry/react'

import { LogEventEnum, LogTypeEnum } from '~/generated/graphql'

import {
  __resetDriftReportingForTests,
  parseSecurityLogResource,
} from '../parseSecurityLogResource'
import { roleEditedResourceSchema, SecurityLogWithId } from '../securityLogsTypes'

jest.mock('@sentry/react', () => ({
  captureException: jest.fn(),
}))

const createLog = (overrides: Partial<SecurityLogWithId> = {}): SecurityLogWithId => ({
  id: 'log-1',
  logId: 'log-1',
  logEvent: LogEventEnum.UserRoleEdited,
  logType: LogTypeEnum.User,
  deviceInfo: null,
  resources: null,
  loggedAt: '2026-04-21T19:07:04Z',
  userEmail: 'gavin@hooli.com',
  ...overrides,
})

describe('parseSecurityLogResource', () => {
  beforeEach(() => {
    __resetDriftReportingForTests()
    jest.clearAllMocks()
  })

  it('returns the parsed value and does not report when the shape matches', () => {
    const log = createLog({
      resources: {
        email: 'edited@example.com',
        roles: { added: ['manager'], deleted: ['admin'] },
      },
    })

    const parsed = parseSecurityLogResource(roleEditedResourceSchema, log)

    expect(parsed).toEqual({
      email: 'edited@example.com',
      roles: { added: ['manager'], deleted: ['admin'] },
    })
    expect(captureException).not.toHaveBeenCalled()
  })

  it('reports to Sentry when the shape is wrong (the ISSUE-1833 regression case)', () => {
    const log = createLog({
      resources: {
        email: 'edited@example.com',
        roles: { added: 'manager' },
      },
    })

    const parsed = parseSecurityLogResource(roleEditedResourceSchema, log)

    expect(parsed).toBeNull()
    expect(captureException).toHaveBeenCalledTimes(1)

    const [error, context] = (captureException as jest.Mock).mock.calls[0]

    expect(error).toBeInstanceOf(Error)
    expect(error.message).toContain('user_role_edited')
    expect(context.tags).toEqual({
      feature: 'security_logs',
      logEvent: 'user_role_edited',
    })
    expect(context.extra.logId).toBe('log-1')
    expect(context.extra.resources).toEqual({
      email: 'edited@example.com',
      roles: { added: 'manager' },
    })
    expect(context.extra.zodIssues).toBeDefined()
    expect(Array.isArray(context.extra.zodIssues)).toBe(true)
  })

  it('dedupes: only reports once per logEvent per session', () => {
    const log = createLog({ resources: { wrong: 'shape' } })

    parseSecurityLogResource(roleEditedResourceSchema, log)
    parseSecurityLogResource(roleEditedResourceSchema, { ...log, logId: 'log-2' })
    parseSecurityLogResource(roleEditedResourceSchema, { ...log, logId: 'log-3' })

    expect(captureException).toHaveBeenCalledTimes(1)
  })

  it('reports separately for different logEvent values', () => {
    const roleEdited = createLog({
      logEvent: LogEventEnum.UserRoleEdited,
      resources: { wrong: 'shape' },
    })
    const roleCreated = createLog({
      logEvent: LogEventEnum.RoleCreated,
      resources: { wrong: 'shape' },
    })

    parseSecurityLogResource(roleEditedResourceSchema, roleEdited)
    parseSecurityLogResource(roleEditedResourceSchema, roleCreated)

    expect(captureException).toHaveBeenCalledTimes(2)
  })
})
