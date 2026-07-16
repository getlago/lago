import { renderHook } from '@testing-library/react'

import { LogEventEnum, LogTypeEnum } from '~/generated/graphql'

import { SecurityLogWithId } from '../../common/securityLogsTypes'
import { useSecurityLogsFormatting } from '../useSecurityLogsFormatting'

const mockTranslate = jest.fn((key: string, params?: Record<string, unknown>) => {
  if (params) {
    return `translated:${key}:${JSON.stringify(params)}`
  }
  return `translated:${key}`
})

const mockIntlFormatDateTimeOrgaTZ = jest.fn(() => ({
  date: 'Jan 15',
  time: '13:41:39',
  timezone: 'UTC',
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: mockTranslate,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    intlFormatDateTimeOrgaTZ: mockIntlFormatDateTimeOrgaTZ,
  }),
}))

const createMockSecurityLog = (overrides: Partial<SecurityLogWithId> = {}): SecurityLogWithId => ({
  id: 'log-1',
  logId: 'log-1',
  logEvent: LogEventEnum.UserSignedUp,
  logType: LogTypeEnum.User,
  deviceInfo: null,
  resources: null,
  loggedAt: '2025-01-15T13:41:39Z',
  userEmail: 'user@example.com',
  ...overrides,
})

describe('useSecurityLogsFormatting', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('getFormattedLogEvent', () => {
    it.each([
      { logEvent: LogEventEnum.ApiKeyCreated, expected: 'api_key.created' },
      { logEvent: LogEventEnum.ApiKeyDeleted, expected: 'api_key.deleted' },
      { logEvent: LogEventEnum.ApiKeyRotated, expected: 'api_key.rotated' },
      { logEvent: LogEventEnum.ApiKeyUpdated, expected: 'api_key.updated' },
      { logEvent: LogEventEnum.BillingEntityCreated, expected: 'billing_entity.created' },
      { logEvent: LogEventEnum.BillingEntityUpdated, expected: 'billing_entity.updated' },
      { logEvent: LogEventEnum.ExportCreated, expected: 'export.created' },
      { logEvent: LogEventEnum.IntegrationCreated, expected: 'integration.created' },
      { logEvent: LogEventEnum.IntegrationDeleted, expected: 'integration.deleted' },
      { logEvent: LogEventEnum.IntegrationUpdated, expected: 'integration.updated' },
      { logEvent: LogEventEnum.RoleCreated, expected: 'role.created' },
      { logEvent: LogEventEnum.RoleDeleted, expected: 'role.deleted' },
      { logEvent: LogEventEnum.RoleUpdated, expected: 'role.updated' },
      { logEvent: LogEventEnum.UserDeleted, expected: 'user.deleted' },
      { logEvent: LogEventEnum.UserInvited, expected: 'user.invited' },
      { logEvent: LogEventEnum.UserPasswordEdited, expected: 'user.password_edited' },
      {
        logEvent: LogEventEnum.UserPasswordResetRequested,
        expected: 'user.password_reset_requested',
      },
      { logEvent: LogEventEnum.UserRoleEdited, expected: 'user.role_edited' },
      { logEvent: LogEventEnum.UserSignedUp, expected: 'user.signed_up' },
      {
        logEvent: LogEventEnum.WebhookEndpointCreated,
        expected: 'webhook_endpoint.created',
      },
      {
        logEvent: LogEventEnum.WebhookEndpointDeleted,
        expected: 'webhook_endpoint.deleted',
      },
      {
        logEvent: LogEventEnum.WebhookEndpointUpdated,
        expected: 'webhook_endpoint.updated',
      },
      {
        logEvent: LogEventEnum.UserNewDeviceLoggedIn,
        expected: 'user.new_device_logged_in',
      },
    ])('THEN should format $logEvent as "$expected"', ({ logEvent, expected }) => {
      const { result } = renderHook(() => useSecurityLogsFormatting())

      expect(result.current.getFormattedLogEvent(logEvent)).toBe(expected)
    })
  })

  describe('getSecurityLogDescription', () => {
    describe('GIVEN an API key event', () => {
      describe('WHEN the event is ApiKeyCreated with valid resources', () => {
        it('THEN should call translate with api key name and last four', () => {
          const { result } = renderHook(() => useSecurityLogsFormatting())
          const log = createMockSecurityLog({
            logEvent: LogEventEnum.ApiKeyCreated,
            resources: { name: 'My API Key', value_ending: 1234 },
          })

          result.current.getSecurityLogDescription(log)

          expect(mockTranslate).toHaveBeenCalledWith(
            'text_1771937987061yugieyprq64',
            expect.objectContaining({ apiKeyName: 'My API Key', lastFour: 1234 }),
          )
        })
      })

      describe('WHEN the event is ApiKeyDeleted with valid resources', () => {
        it('THEN should call translate with api key name and last four', () => {
          const { result } = renderHook(() => useSecurityLogsFormatting())
          const log = createMockSecurityLog({
            logEvent: LogEventEnum.ApiKeyDeleted,
            resources: { name: 'Old Key', value_ending: 5678 },
          })

          result.current.getSecurityLogDescription(log)

          expect(mockTranslate).toHaveBeenCalledWith(
            'text_1771937987062c4wpkhw85ur',
            expect.objectContaining({ apiKeyName: 'Old Key', lastFour: 5678 }),
          )
        })
      })

      describe('WHEN the event is ApiKeyRotated with valid resources', () => {
        it('THEN should call translate with api key name, old and new last four', () => {
          const { result } = renderHook(() => useSecurityLogsFormatting())
          const log = createMockSecurityLog({
            logEvent: LogEventEnum.ApiKeyRotated,
            resources: {
              name: 'Rotated Key',
              value_ending: { deleted: 'AAAA', added: 'BBBB' },
            },
          })

          result.current.getSecurityLogDescription(log)

          expect(mockTranslate).toHaveBeenCalledWith(
            'text_1771937987062j5wceattpsk',
            expect.objectContaining({
              apiKeyName: 'Rotated Key',
              lastFourFrom: 'AAAA',
              lastFourTo: 'BBBB',
            }),
          )
        })
      })

      describe('WHEN the event is ApiKeyUpdated with valid resources', () => {
        it('THEN should call translate with api key name and last four', () => {
          const { result } = renderHook(() => useSecurityLogsFormatting())
          const log = createMockSecurityLog({
            logEvent: LogEventEnum.ApiKeyUpdated,
            resources: { name: 'Updated Key', value_ending: 9012 },
          })

          result.current.getSecurityLogDescription(log)

          expect(mockTranslate).toHaveBeenCalledWith(
            'text_17719379870627ay1unhe3sc',
            expect.objectContaining({ apiKeyName: 'Updated Key', lastFour: 9012 }),
          )
        })
      })
    })

    describe('GIVEN a billing entity event', () => {
      it.each([
        { event: LogEventEnum.BillingEntityCreated, key: 'text_1771937987062m168k1ib517' },
        { event: LogEventEnum.BillingEntityUpdated, key: 'text_1771937987062jvw6fuaozy6' },
      ])(
        'THEN should call translate for $event with email and billing entity name',
        ({ event, key }) => {
          const { result } = renderHook(() => useSecurityLogsFormatting())
          const log = createMockSecurityLog({
            logEvent: event,
            resources: { billing_entity_name: 'Acme Corp' },
          })

          result.current.getSecurityLogDescription(log)

          expect(mockTranslate).toHaveBeenCalledWith(
            key,
            expect.objectContaining({
              email: 'user@example.com',
              billingEntityName: 'Acme Corp',
            }),
          )
        },
      )
    })

    describe('GIVEN an export event', () => {
      describe('WHEN the event is ExportCreated', () => {
        it('THEN should call translate with email', () => {
          const { result } = renderHook(() => useSecurityLogsFormatting())
          const log = createMockSecurityLog({
            logEvent: LogEventEnum.ExportCreated,
          })

          result.current.getSecurityLogDescription(log)

          expect(mockTranslate).toHaveBeenCalledWith(
            'text_17719379870627ei3dm7ewsz',
            expect.objectContaining({ email: 'user@example.com' }),
          )
        })
      })
    })

    describe('GIVEN an integration event', () => {
      it.each([
        { event: LogEventEnum.IntegrationCreated, key: 'text_1771937987062d55u36jsdpr' },
        { event: LogEventEnum.IntegrationDeleted, key: 'text_1771937987062a3v2gpxuc0r' },
        { event: LogEventEnum.IntegrationUpdated, key: 'text_1771937987062w21v4p2bnf8' },
      ])(
        'THEN should call translate for $event with email and integration name',
        ({ event, key }) => {
          const { result } = renderHook(() => useSecurityLogsFormatting())
          const log = createMockSecurityLog({
            logEvent: event,
            resources: { integration_name: 'Stripe' },
          })

          result.current.getSecurityLogDescription(log)

          expect(mockTranslate).toHaveBeenCalledWith(
            key,
            expect.objectContaining({
              email: 'user@example.com',
              integrationName: 'Stripe',
            }),
          )
        },
      )
    })

    describe('GIVEN a role event', () => {
      it.each([
        { event: LogEventEnum.RoleCreated, key: 'text_17719379870626yw59p9eb05' },
        { event: LogEventEnum.RoleDeleted, key: 'text_1771937987062w0rqek89vln' },
        { event: LogEventEnum.RoleUpdated, key: 'text_17719379870621tc4rrbq2q1' },
      ])('THEN should call translate for $event with email and role', ({ event, key }) => {
        const { result } = renderHook(() => useSecurityLogsFormatting())
        const log = createMockSecurityLog({
          logEvent: event,
          resources: { role_code: 'admin' },
        })

        result.current.getSecurityLogDescription(log)

        expect(mockTranslate).toHaveBeenCalledWith(
          key,
          expect.objectContaining({
            email: 'user@example.com',
            role: 'admin',
          }),
        )
      })
    })

    describe('GIVEN a user event', () => {
      describe('WHEN the event is UserDeleted', () => {
        it('THEN should call translate with email', () => {
          const { result } = renderHook(() => useSecurityLogsFormatting())
          const log = createMockSecurityLog({
            logEvent: LogEventEnum.UserDeleted,
          })

          result.current.getSecurityLogDescription(log)

          expect(mockTranslate).toHaveBeenCalledWith(
            'text_1771937987062gcohii3uw0b',
            expect.objectContaining({ email: 'user@example.com' }),
          )
        })
      })

      describe('WHEN the event is UserInvited with valid resources', () => {
        it('THEN should call translate with inviter and invitee emails', () => {
          const { result } = renderHook(() => useSecurityLogsFormatting())
          const log = createMockSecurityLog({
            logEvent: LogEventEnum.UserInvited,
            resources: { invitee_email: 'invitee@example.com' },
          })

          result.current.getSecurityLogDescription(log)

          expect(mockTranslate).toHaveBeenCalledWith(
            'text_1771937987062y18loukkg7e',
            expect.objectContaining({
              emailInviter: 'user@example.com',
              emailInvitee: 'invitee@example.com',
            }),
          )
        })
      })

      it.each([
        { event: LogEventEnum.UserPasswordEdited, key: 'text_1771937987062gk7g578r4jp' },
        { event: LogEventEnum.UserPasswordResetRequested, key: 'text_1771937987062l3bixv068cp' },
        { event: LogEventEnum.UserSignedUp, key: 'text_1771937987062jy68yxfqjwx' },
        { event: LogEventEnum.UserNewDeviceLoggedIn, key: 'text_1773415705134l01iamqr6fk' },
      ])('THEN should call translate for $event with email', ({ event, key }) => {
        const { result } = renderHook(() => useSecurityLogsFormatting())
        const log = createMockSecurityLog({
          logEvent: event,
        })

        result.current.getSecurityLogDescription(log)

        expect(mockTranslate).toHaveBeenCalledWith(
          key,
          expect.objectContaining({ email: 'user@example.com' }),
        )
      })

      describe('WHEN the event is UserRoleEdited', () => {
        it('THEN uses the "both" key when roles are both added and removed', () => {
          const { result } = renderHook(() => useSecurityLogsFormatting())
          const log = createMockSecurityLog({
            logEvent: LogEventEnum.UserRoleEdited,
            resources: {
              email: 'edited@example.com',
              roles: { added: ['manager', 'viewer'], deleted: ['admin'] },
            },
          })

          result.current.getSecurityLogDescription(log)

          expect(mockTranslate).toHaveBeenCalledWith('text_17767988500520plhs9f7tkm', {
            emailUpdated: 'edited@example.com',
            rolesAdded: 'manager, viewer',
            rolesDeleted: 'admin',
            emailUpdater: 'user@example.com',
          })
        })

        it('THEN uses the "added-only" key when only new roles are assigned', () => {
          const { result } = renderHook(() => useSecurityLogsFormatting())
          const log = createMockSecurityLog({
            logEvent: LogEventEnum.UserRoleEdited,
            resources: {
              email: 'edited@example.com',
              roles: { added: ['manager'] },
            },
          })

          result.current.getSecurityLogDescription(log)

          expect(mockTranslate).toHaveBeenCalledWith('text_17767988500524o9o9mr53rq', {
            emailUpdated: 'edited@example.com',
            rolesAdded: 'manager',
            emailUpdater: 'user@example.com',
          })
        })

        it('THEN uses the "deleted-only" key when only roles are removed', () => {
          const { result } = renderHook(() => useSecurityLogsFormatting())
          const log = createMockSecurityLog({
            logEvent: LogEventEnum.UserRoleEdited,
            resources: {
              email: 'edited@example.com',
              roles: { deleted: ['admin'] },
            },
          })

          result.current.getSecurityLogDescription(log)

          expect(mockTranslate).toHaveBeenCalledWith('text_177679885005270syn8w6fh8', {
            emailUpdated: 'edited@example.com',
            rolesDeleted: 'admin',
            emailUpdater: 'user@example.com',
          })
        })

        it('THEN falls back to unknown when the payload uses the outdated string shape', () => {
          // Guards against regressing to the pre-ISSUE-1833 shape where
          // `roles.added` was a string instead of an array.
          const { result } = renderHook(() => useSecurityLogsFormatting())
          const log = createMockSecurityLog({
            logEvent: LogEventEnum.UserRoleEdited,
            resources: {
              email: 'edited@example.com',
              roles: { added: 'manager' },
            },
          })

          result.current.getSecurityLogDescription(log)

          expect(mockTranslate).toHaveBeenCalledWith('text_17767988500520plhs9f7tkm', {
            emailUpdated: 'unknown',
            rolesAdded: 'unknown',
            rolesDeleted: 'unknown',
            emailUpdater: 'user@example.com',
          })
        })
      })
    })

    describe('GIVEN a webhook endpoint event', () => {
      it.each([
        { event: LogEventEnum.WebhookEndpointCreated, key: 'text_1771937987062g2z0d9cegyj' },
        { event: LogEventEnum.WebhookEndpointDeleted, key: 'text_177193798706284nfb2tmxkb' },
      ])('THEN should call translate for $event with webhook url', ({ event, key }) => {
        const { result } = renderHook(() => useSecurityLogsFormatting())
        const log = createMockSecurityLog({
          logEvent: event,
          resources: { webhook_url: 'https://example.com/webhook' },
        })

        result.current.getSecurityLogDescription(log)

        expect(mockTranslate).toHaveBeenCalledWith(
          key,
          expect.objectContaining({ url: 'https://example.com/webhook' }),
        )
      })

      it('THEN should call translate for WebhookEndpointUpdated with edited webhook urls', () => {
        const { result } = renderHook(() => useSecurityLogsFormatting())
        const log = createMockSecurityLog({
          logEvent: LogEventEnum.WebhookEndpointUpdated,
          resources: {
            webhook_url: {
              deleted: 'https://old.example.com/webhook',
              added: 'https://new.example.com/webhook',
            },
          },
        })

        result.current.getSecurityLogDescription(log)

        expect(mockTranslate).toHaveBeenCalledWith(
          'text_1771937987062rw8agotc8gs',
          expect.objectContaining({
            urlFrom: 'https://old.example.com/webhook',
            urlTo: 'https://new.example.com/webhook',
          }),
        )
      })

      it('THEN should call translate for WebhookEndpointUpdated with the algorithm copy when only the signature algorithm changed', () => {
        // Regression test for FRONT-15Y: the backend sends webhook_url as a
        // plain string when unchanged, alongside a signature_algo diff.
        const { result } = renderHook(() => useSecurityLogsFormatting())
        const log = createMockSecurityLog({
          logEvent: LogEventEnum.WebhookEndpointUpdated,
          resources: {
            webhook_url: 'https://example.com/webhook',
            signature_algo: { deleted: 'hmac', added: 'jwt' },
          },
        })

        result.current.getSecurityLogDescription(log)

        expect(mockTranslate).toHaveBeenCalledWith('text_17810792697743rdztc0hzsn', {
          algoFrom: 'hmac',
          algoTo: 'jwt',
        })
      })

      it('THEN should call translate for WebhookEndpointUpdated with the combined copy when both url and signature algorithm changed', () => {
        const { result } = renderHook(() => useSecurityLogsFormatting())
        const log = createMockSecurityLog({
          logEvent: LogEventEnum.WebhookEndpointUpdated,
          resources: {
            webhook_url: {
              deleted: 'https://old.example.com/webhook',
              added: 'https://new.example.com/webhook',
            },
            signature_algo: { deleted: 'hmac', added: 'jwt' },
          },
        })

        result.current.getSecurityLogDescription(log)

        expect(mockTranslate).toHaveBeenCalledWith('text_1781079269774kur4mhrgipy', {
          urlFrom: 'https://old.example.com/webhook',
          urlTo: 'https://new.example.com/webhook',
          algoFrom: 'hmac',
          algoTo: 'jwt',
        })
      })

      it('THEN falls back to unknown for WebhookEndpointUpdated when the url is unchanged and no algorithm change is present', () => {
        const { result } = renderHook(() => useSecurityLogsFormatting())
        const log = createMockSecurityLog({
          logEvent: LogEventEnum.WebhookEndpointUpdated,
          resources: { webhook_url: 'https://example.com/webhook' },
        })

        result.current.getSecurityLogDescription(log)

        expect(mockTranslate).toHaveBeenCalledWith('text_1771937987062rw8agotc8gs', {
          urlFrom: 'unknown',
          urlTo: 'unknown',
        })
      })

      it('THEN falls back to unknown for WebhookEndpointUpdated when the payload shape is not recognized', () => {
        const { result } = renderHook(() => useSecurityLogsFormatting())
        const log = createMockSecurityLog({
          logEvent: LogEventEnum.WebhookEndpointUpdated,
          resources: { webhook_url: 123 },
        })

        result.current.getSecurityLogDescription(log)

        expect(mockTranslate).toHaveBeenCalledWith('text_1771937987062rw8agotc8gs', {
          urlFrom: 'unknown',
          urlTo: 'unknown',
        })
      })
    })

    describe('GIVEN an unknown event', () => {
      describe('WHEN the event is not in the switch statement', () => {
        it('THEN should return a dash', () => {
          const { result } = renderHook(() => useSecurityLogsFormatting())
          const log = createMockSecurityLog({
            logEvent: 'unknown_event' as LogEventEnum,
          })

          const description = result.current.getSecurityLogDescription(log)

          expect(description).toBe('-')
        })
      })
    })
  })

  describe('getSecurityLogDate', () => {
    describe('GIVEN a security log with a loggedAt timestamp', () => {
      describe('WHEN getSecurityLogDate is called', () => {
        it('THEN should format the date and time using organization timezone', () => {
          const { result } = renderHook(() => useSecurityLogsFormatting())
          const log = createMockSecurityLog({
            loggedAt: '2025-01-15T13:41:39Z',
          })

          const formattedDate = result.current.getSecurityLogDate(log)

          expect(mockIntlFormatDateTimeOrgaTZ).toHaveBeenCalledWith('2025-01-15T13:41:39Z', {
            formatTime: 'TIME_24_WITH_SECONDS',
            formatDate: 'DATE_MED_SHORT',
          })
          expect(formattedDate).toBe('Jan 15, 13:41:39')
        })
      })
    })
  })
})
