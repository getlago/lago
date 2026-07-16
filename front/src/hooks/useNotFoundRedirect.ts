import { ApolloError } from '@apollo/client'
import { captureException } from '@sentry/react'
import { useEffect } from 'react'

import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { useNavigate } from '~/core/router'

type UseNotFoundRedirectArgs = {
  error: ApolloError | undefined
  loading: boolean
  redirectTo: string
  translateKey: string
}

export const useNotFoundRedirect = ({
  error,
  loading,
  redirectTo,
  translateKey,
}: UseNotFoundRedirectArgs) => {
  const navigate = useNavigate()
  const isNotFoundError = hasDefinedGQLError('NotFound', error)

  useEffect(() => {
    if (loading || !isNotFoundError) return

    captureException(error, {
      tags: {
        errorType: 'NotFoundRedirect',
        fromPath: window.location.pathname,
        redirectTo,
      },
    })

    addToast({
      severity: 'info',
      translateKey,
    })
    navigate(redirectTo, { replace: true })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loading, isNotFoundError])
}
