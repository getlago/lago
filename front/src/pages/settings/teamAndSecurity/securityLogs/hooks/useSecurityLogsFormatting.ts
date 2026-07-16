import { DateFormat, TimeFormat } from '~/core/timezone'
import { LogEventEnum, LogTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

import { parseSecurityLogResource } from '../common/parseSecurityLogResource'
import {
  apiKeyResourceSchema,
  billingEntityResourceSchema,
  integrationResourceSchema,
  inviteResourceSchema,
  roleEditedResourceSchema,
  roleResourceSchema,
  rotatedApiKeyResourceSchema,
  SecurityLogWithId,
  webhookEditedResourceSchema,
  webhookResourceSchema,
} from '../common/securityLogsTypes'

export const useSecurityLogsFormatting = () => {
  const { translate } = useInternationalization()
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()

  const getFormattedLogEvent = (logEvent: LogEventEnum) => {
    const logTypes = Object.values(LogTypeEnum).sort((a, b) => b.length - a.length)

    for (const logType of logTypes) {
      const prefix = `${logType}_`

      if (logEvent.startsWith(prefix)) {
        return `${logType}.${logEvent.slice(prefix.length)}`
      }
    }

    return logEvent
  }

  const getApiKeyResources = (securityLog: SecurityLogWithId) => {
    const parsed = parseSecurityLogResource(apiKeyResourceSchema, securityLog)

    if (!parsed) return { apiKeyName: 'unknown', lastFour: 'XXXX' }

    return {
      apiKeyName: parsed.name,
      lastFour: parsed.value_ending,
    }
  }

  const getRotatedApiKeyResources = (securityLog: SecurityLogWithId) => {
    const parsed = parseSecurityLogResource(rotatedApiKeyResourceSchema, securityLog)

    if (!parsed) return { apiKeyName: 'unknown', lastFourFrom: 'XXXX', lastFourTo: 'XXXX' }

    return {
      apiKeyName: parsed.name,
      lastFourFrom: parsed.value_ending.deleted,
      lastFourTo: parsed.value_ending.added,
    }
  }

  const getBillingEntityResources = (securityLog: SecurityLogWithId) => {
    const parsed = parseSecurityLogResource(billingEntityResourceSchema, securityLog)

    if (!parsed) return { email: securityLog.userEmail, billingEntityName: 'unknown' }

    return {
      email: securityLog.userEmail,
      billingEntityName: parsed.billing_entity_name,
    }
  }

  const getIntegrationsResources = (securityLog: SecurityLogWithId) => {
    const parsed = parseSecurityLogResource(integrationResourceSchema, securityLog)

    if (!parsed) return { email: securityLog.userEmail, integrationName: 'unknown' }

    return {
      email: securityLog.userEmail,
      integrationName: parsed.integration_name,
    }
  }

  const getRoleResources = (securityLog: SecurityLogWithId) => {
    const parsed = parseSecurityLogResource(roleResourceSchema, securityLog)

    if (!parsed) return { email: securityLog.userEmail, role: 'unknown' }

    return {
      email: securityLog.userEmail,
      role: parsed.role_code,
    }
  }

  const getInviteResources = (securityLog: SecurityLogWithId) => {
    const parsed = parseSecurityLogResource(inviteResourceSchema, securityLog)

    if (!parsed) return { emailInviter: securityLog.userEmail, emailInvitee: 'unknown' }

    return {
      emailInviter: securityLog.userEmail,
      emailInvitee: parsed.invitee_email,
    }
  }

  const getRoleEditedTranslation = (securityLog: SecurityLogWithId) => {
    const parsed = parseSecurityLogResource(roleEditedResourceSchema, securityLog)

    if (!parsed) {
      return translate('text_17767988500520plhs9f7tkm', {
        emailUpdated: 'unknown',
        rolesAdded: 'unknown',
        rolesDeleted: 'unknown',
        emailUpdater: securityLog.userEmail,
      })
    }

    const rolesAdded = parsed.roles.added?.join(', ')
    const rolesDeleted = parsed.roles.deleted?.join(', ')

    if (rolesAdded && rolesDeleted) {
      return translate('text_17767988500520plhs9f7tkm', {
        emailUpdated: parsed.email,
        rolesAdded,
        rolesDeleted,
        emailUpdater: securityLog.userEmail,
      })
    }

    if (rolesAdded) {
      return translate('text_17767988500524o9o9mr53rq', {
        emailUpdated: parsed.email,
        rolesAdded,
        emailUpdater: securityLog.userEmail,
      })
    }

    return translate('text_177679885005270syn8w6fh8', {
      emailUpdated: parsed.email,
      rolesDeleted,
      emailUpdater: securityLog.userEmail,
    })
  }

  const getWebhookResources = (securityLog: SecurityLogWithId) => {
    const parsed = parseSecurityLogResource(webhookResourceSchema, securityLog)

    if (!parsed) return { url: 'unknown' }

    return {
      url: parsed.webhook_url,
    }
  }

  const getWebhookEditedDescription = (securityLog: SecurityLogWithId) => {
    const parsed = parseSecurityLogResource(webhookEditedResourceSchema, securityLog)

    if (!parsed)
      return translate('text_1771937987062rw8agotc8gs', { urlFrom: 'unknown', urlTo: 'unknown' })

    const { webhook_url, signature_algo } = parsed
    const urlDiff = typeof webhook_url === 'object' ? webhook_url : null

    if (urlDiff && signature_algo) {
      return translate('text_1781079269774kur4mhrgipy', {
        urlFrom: urlDiff.deleted,
        urlTo: urlDiff.added,
        algoFrom: signature_algo.deleted,
        algoTo: signature_algo.added,
      })
    }

    if (signature_algo) {
      return translate('text_17810792697743rdztc0hzsn', {
        algoFrom: signature_algo.deleted,
        algoTo: signature_algo.added,
      })
    }

    if (urlDiff) {
      return translate('text_1771937987062rw8agotc8gs', {
        urlFrom: urlDiff.deleted,
        urlTo: urlDiff.added,
      })
    }

    // webhook_url is a string and no signature_algo change — nothing meaningful to show
    return translate('text_1771937987062rw8agotc8gs', { urlFrom: 'unknown', urlTo: 'unknown' })
  }

  const getSecurityLogDescription = (securityLog: SecurityLogWithId) => {
    switch (securityLog.logEvent) {
      case LogEventEnum.ApiKeyCreated:
        return translate('text_1771937987061yugieyprq64', getApiKeyResources(securityLog))
      case LogEventEnum.ApiKeyDeleted:
        return translate('text_1771937987062c4wpkhw85ur', getApiKeyResources(securityLog))
      case LogEventEnum.ApiKeyRotated:
        return translate('text_1771937987062j5wceattpsk', getRotatedApiKeyResources(securityLog))
      case LogEventEnum.ApiKeyUpdated:
        return translate('text_17719379870627ay1unhe3sc', getApiKeyResources(securityLog))
      case LogEventEnum.BillingEntityCreated:
        return translate('text_1771937987062m168k1ib517', getBillingEntityResources(securityLog))
      case LogEventEnum.BillingEntityUpdated:
        return translate('text_1771937987062jvw6fuaozy6', getBillingEntityResources(securityLog))
      case LogEventEnum.ExportCreated:
        return translate('text_17719379870627ei3dm7ewsz', {
          email: securityLog.userEmail,
        })
      case LogEventEnum.IntegrationCreated:
        return translate('text_1771937987062d55u36jsdpr', getIntegrationsResources(securityLog))
      case LogEventEnum.IntegrationDeleted:
        return translate('text_1771937987062a3v2gpxuc0r', getIntegrationsResources(securityLog))
      case LogEventEnum.IntegrationUpdated:
        return translate('text_1771937987062w21v4p2bnf8', getIntegrationsResources(securityLog))
      case LogEventEnum.RoleCreated:
        return translate('text_17719379870626yw59p9eb05', getRoleResources(securityLog))
      case LogEventEnum.RoleDeleted:
        return translate('text_1771937987062w0rqek89vln', getRoleResources(securityLog))
      case LogEventEnum.RoleUpdated:
        return translate('text_17719379870621tc4rrbq2q1', getRoleResources(securityLog))
      case LogEventEnum.UserDeleted:
        return translate('text_1771937987062gcohii3uw0b', {
          email: securityLog.userEmail,
        })
      case LogEventEnum.UserInvited:
        return translate('text_1771937987062y18loukkg7e', getInviteResources(securityLog))
      case LogEventEnum.UserPasswordEdited:
        return translate('text_1771937987062gk7g578r4jp', {
          email: securityLog.userEmail,
        })
      case LogEventEnum.UserPasswordResetRequested:
        return translate('text_1771937987062l3bixv068cp', {
          email: securityLog.userEmail,
        })
      case LogEventEnum.UserRoleEdited:
        return getRoleEditedTranslation(securityLog)
      case LogEventEnum.UserSignedUp:
        return translate('text_1771937987062jy68yxfqjwx', {
          email: securityLog.userEmail,
        })
      case LogEventEnum.WebhookEndpointCreated:
        return translate('text_1771937987062g2z0d9cegyj', getWebhookResources(securityLog))
      case LogEventEnum.WebhookEndpointDeleted:
        return translate('text_177193798706284nfb2tmxkb', getWebhookResources(securityLog))
      case LogEventEnum.WebhookEndpointUpdated:
        return getWebhookEditedDescription(securityLog)
      case LogEventEnum.UserNewDeviceLoggedIn:
        return translate('text_1773415705134l01iamqr6fk', {
          email: securityLog.userEmail,
        })
      default:
        return '-'
    }
  }

  const getSecurityLogDate = (securityLog: SecurityLogWithId) => {
    const formattedTime = intlFormatDateTimeOrgaTZ(securityLog.loggedAt, {
      formatTime: TimeFormat.TIME_24_WITH_SECONDS,
      formatDate: DateFormat.DATE_MED_SHORT,
    })

    return `${formattedTime.date}, ${formattedTime.time}`
  }

  return {
    getFormattedLogEvent,
    getSecurityLogDescription,
    getSecurityLogDate,
  }
}
