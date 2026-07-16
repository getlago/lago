import { ApolloError } from '@apollo/client'
import * as Sentry from '@sentry/react'
import { ReactNode } from 'react'

import { addToast } from '~/core/apolloClient'

interface ErrorBoundaryProps {
  children: ReactNode
}

export const ErrorBoundary = ({ children }: ErrorBoundaryProps) => {
  return (
    <Sentry.ErrorBoundary
      beforeCapture={(scope) => {
        scope.setTag('component', 'ErrorBoundary')
      }}
      showDialog={false}
      onError={(error, componentStack, eventId) => {
        // Add detailed error info to Sentry context
        Sentry.withScope((scope) => {
          scope.setLevel('error')
          scope.setTag('errorBoundary', 'App')
          scope.setTag('errorCategory', 'global')

          // Type guard for Error objects
          // Sentry automatically extracts error.message and error.stack for Error objects
          // We only add custom tag for filtering/grouping and handle non-Error objects
          if (error instanceof Error) {
            scope.setTag('errorType', error.name || 'UnknownError')
          } else {
            scope.setTag('errorType', 'UnknownError')
            scope.setExtra('error', String(error))
          }

          scope.setExtra('componentStack', componentStack)
          scope.setExtra('sentryEventId', eventId)

          // Add URL context
          if (typeof window !== 'undefined') {
            scope.setExtra('url', window.location.href)
            scope.setExtra('pathname', window.location.pathname)
            scope.setExtra('referrer', document.referrer)
          }

          Sentry.captureException(error)
        })

        // Only show toast notification if not an Apollo/GraphQL error
        // Apollo errors are already handled in apollo init.ts
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
