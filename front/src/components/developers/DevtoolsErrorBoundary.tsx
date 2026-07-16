import { ApolloError } from '@apollo/client'
import * as Sentry from '@sentry/react'
import { ReactNode } from 'react'

import { addToast } from '~/core/apolloClient'
import { useLocation } from '~/core/router'

interface DevtoolsErrorBoundaryProps {
  children: ReactNode
}

export const DevtoolsErrorBoundary = ({ children }: DevtoolsErrorBoundaryProps) => {
  const { pathname: devtoolsPathname } = useLocation()

  return (
    <Sentry.ErrorBoundary
      beforeCapture={(scope) => {
        scope.setTag('component', 'DevtoolsErrorBoundary')
      }}
      showDialog={false}
      onError={(error, componentStack, eventId) => {
        Sentry.withScope((scope) => {
          scope.setLevel('error')
          scope.setTag('errorBoundary', 'App')
          scope.setTag('errorCategory', 'Devtools')

          if (error instanceof Error) {
            scope.setTag('errorType', error.name || 'UnknownError')
          } else {
            scope.setTag('errorType', 'UnknownError')
            scope.setExtra('error', String(error))
          }

          scope.setExtra('componentStack', componentStack)
          scope.setExtra('sentryEventId', eventId)

          // Add both router contexts for debugging
          if (typeof window !== 'undefined') {
            scope.setExtra('url', window.location.href)
            scope.setExtra('pathname', window.location.pathname)
            scope.setExtra('devtoolsPathname', devtoolsPathname)
            scope.setExtra('referrer', document.referrer)
          }

          Sentry.captureException(error)
        })

        if (!(error instanceof ApolloError)) {
          addToast({
            severity: 'danger',
            translateKey: 'text_622f7a3dc32ce100c46a5154',
          })
        }
      }}
    >
      {children}
    </Sentry.ErrorBoundary>
  )
}
