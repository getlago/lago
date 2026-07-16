import * as Sentry from '@sentry/react'
import React from 'react'
import { createRoot } from 'react-dom/client'

import App from '~/App'
import { envGlobalVar } from '~/core/apolloClient'
import { AppEnvEnum } from '~/core/constants/globalTypes'
import { getEnableFeatureFlags, listFeatureFlags, setFeatureFlags } from '~/core/utils/featureFlags'

import './main.css'

const { appEnv, sentryDsn, appVersion } = envGlobalVar()

if (!!sentryDsn && appEnv !== AppEnvEnum.development) {
  Sentry.init({
    dsn: sentryDsn,
    integrations: [
      Sentry.browserTracingIntegration(),
      Sentry.replayIntegration({
        maskAllText: false,
        blockAllMedia: false,
        maskAllInputs: false,
      }),
    ],
    environment: appEnv,
    // Increase depth for nested objects (default is 3) to capture full GraphQL error details
    normalizeDepth: 10,
    // Increase max string length (default is 250) for error details
    maxValueLength: 2000,
    // Prevent sending recorded session if no error occurs
    replaysSessionSampleRate: 0.0,
    // Buffer (locally recorded) and send 30% of errors if one occurs
    replaysOnErrorSampleRate: 0.3,
    // Collect traces for 30% of sessions
    tracesSampleRate: 0.3,
    // Release tracking - essential for source maps
    release: appVersion,
    // Attach stack traces to all messages
    attachStacktrace: true,
    // Filter out common browser extension errors and noise
    ignoreErrors: [
      // Chrome extensions
      /chrome-extension:/i,
      /moz-extension:/i,
      // Safari extensions
      /safari-extension:/i,
      // Generic script errors from extensions
      /^Script error\.?$/i,
      /^Javascript error: Script error\.? on line 0$/i,
      // Apollo Client abort errors (user navigating away, component unmounting, etc.)
      // Matches "signal aborted", "AbortError: signal aborted", etc.
      /signal aborted/i,
      // Also catch generic AbortError messages
      'AbortError',
      // Browser extension / antivirus COM automation errors (Kaspersky, Norton, etc.)
      /Object Not Found Matching Id/i,
    ],
    // Deny URLs from browser extensions and other noise
    denyUrls: [
      // Chrome extensions
      /extensions\//i,
      /^chrome:\/\//i,
      /^chrome-extension:\/\//i,
      // Firefox extensions
      /^resource:\/\//i,
      /^moz-extension:\/\//i,
      // Safari extensions
      /^safari-extension:\/\//i,
    ],
  })
}

if (appEnv !== AppEnvEnum.production) {
  window.Lago = {
    getEnableFeatureFlags: getEnableFeatureFlags,
    setFeatureFlags: setFeatureFlags,
    listFeatureFlags: listFeatureFlags,
  }

  const style = 'background: #eee; color: #fe3d3d'
  const logs = [
    'List available flags: %c window.Lago.listFeatureFlags() ',
    "Set single flag: %c window.Lago.setFeatureFlags('ftr_xxx_enabled') ",
    "Set multiple flags: %c window.Lago.setFeatureFlags(['ftr_xxx_enabled', 'ftr_yyy_enabled']) ",
    "Set all flags: %c window.Lago.setFeatureFlags('all') ",
    'Get enable flags: %c window.Lago.getEnableFeatureFlags() ',
  ]

  /* eslint-disable no-console */
  console.groupCollapsed('%c window.Lago is available', style)
  logs.forEach((log) => console.info(log, style))
  console.groupEnd()
  /* eslint-enable no-console */
}

// eslint-disable-next-line @typescript-eslint/no-non-null-assertion
const container = document.getElementById('root')!

createRoot(container).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
