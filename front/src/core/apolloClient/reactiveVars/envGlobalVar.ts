import { makeVar } from '@apollo/client'

import { AppEnvEnum } from '~/core/constants/globalTypes'

interface EnvGlobal {
  appEnv: AppEnvEnum
  apiUrl: string
  lagoOauthProxyUrl: string
  disableSignUp: boolean
  appVersion: string
  nangoPublicKey: string
  sentryDsn: string
  disablePdfGeneration: boolean
  lagoSupersetUrl: string
}

const getApiUrl = () => {
  if (!!window.API_URL) return window.API_URL
  if (!!window.LAGO_DOMAIN) return `https://${window.LAGO_DOMAIN}/api`
  return API_URL
}

export const envGlobalVar = makeVar<EnvGlobal>({
  apiUrl: getApiUrl(),
  appEnv: window.APP_ENV || APP_ENV,
  lagoOauthProxyUrl: window.LAGO_OAUTH_PROXY_URL || LAGO_OAUTH_PROXY_URL,
  disableSignUp: (window.LAGO_DISABLE_SIGNUP || LAGO_DISABLE_SIGNUP) === 'true',
  appVersion: APP_VERSION,
  nangoPublicKey: window.NANGO_PUBLIC_KEY || NANGO_PUBLIC_KEY,
  sentryDsn: window.SENTRY_DSN || SENTRY_DSN,
  disablePdfGeneration:
    (window.LAGO_DISABLE_PDF_GENERATION || LAGO_DISABLE_PDF_GENERATION) === 'true',
  lagoSupersetUrl: window.LAGO_SUPERSET_URL || LAGO_SUPERSET_URL,
})
