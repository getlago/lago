import { LogEventEnum, LogTypeEnum } from '~/generated/graphql'

import { formatSecurityLogs } from '../useSecurityLogs'

describe('useSecurityLogs', () => {
  describe('formatSecurityLogs', () => {
    describe('GIVEN a list of security logs', () => {
      describe('WHEN formatSecurityLogs is called with valid data', () => {
        it('THEN should add an id field from logId to each log', () => {
          const logs = [
            {
              logId: 'log-1',
              logEvent: LogEventEnum.UserSignedUp,
              logType: LogTypeEnum.User,
              deviceInfo: null,
              resources: null,
              loggedAt: '2025-01-15T13:41:39Z',
              userEmail: 'user@example.com',
            },
            {
              logId: 'log-2',
              logEvent: LogEventEnum.ApiKeyCreated,
              logType: LogTypeEnum.ApiKey,
              deviceInfo: { browser: 'Chrome' },
              resources: { name: 'Test Key', value_ending: '1234' },
              loggedAt: '2025-01-16T10:00:00Z',
              userEmail: 'admin@example.com',
            },
          ]

          const result = formatSecurityLogs(logs)

          expect(result).toHaveLength(2)
          expect(result[0]).toEqual(
            expect.objectContaining({
              id: 'log-1',
              logId: 'log-1',
              logEvent: LogEventEnum.UserSignedUp,
              userEmail: 'user@example.com',
            }),
          )
          expect(result[1]).toEqual(
            expect.objectContaining({
              id: 'log-2',
              logId: 'log-2',
              logEvent: LogEventEnum.ApiKeyCreated,
              userEmail: 'admin@example.com',
            }),
          )
        })
      })

      describe('WHEN formatSecurityLogs is called with an empty array', () => {
        it('THEN should return an empty array', () => {
          const result = formatSecurityLogs([])

          expect(result).toEqual([])
        })
      })
    })

    describe('GIVEN a single security log', () => {
      describe('WHEN formatSecurityLogs is called', () => {
        it('THEN should preserve all original fields alongside the new id field', () => {
          const logs = [
            {
              logId: 'log-3',
              logEvent: LogEventEnum.ExportCreated,
              logType: LogTypeEnum.Export,
              deviceInfo: { browser: 'Firefox' },
              resources: null,
              loggedAt: '2025-02-01T09:00:00Z',
              userEmail: 'export@example.com',
            },
          ]

          const result = formatSecurityLogs(logs)

          expect(result).toHaveLength(1)
          expect(result[0]).toEqual({
            id: 'log-3',
            logId: 'log-3',
            logEvent: LogEventEnum.ExportCreated,
            logType: LogTypeEnum.Export,
            deviceInfo: { browser: 'Firefox' },
            resources: null,
            loggedAt: '2025-02-01T09:00:00Z',
            userEmail: 'export@example.com',
          })
        })
      })
    })
  })
})
