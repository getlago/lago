import { useReactiveVar } from '@apollo/client'

import { authTokenVar, customerPortalTokenVar } from '~/core/apolloClient'

type useIsAuthenticatedReturn = () => {
  isAuthenticated: boolean
  isPortalAuthenticated: boolean
  token?: string
}

export const useIsAuthenticated: useIsAuthenticatedReturn = () => {
  const token = useReactiveVar(authTokenVar)
  const portalToken = useReactiveVar(customerPortalTokenVar)

  return {
    isAuthenticated: !!token,
    isPortalAuthenticated: !!portalToken,
    token,
  }
}
