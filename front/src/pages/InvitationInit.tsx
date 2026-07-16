import { useApolloClient } from '@apollo/client'
import { useEffect } from 'react'
import { generatePath, Outlet, useParams } from 'react-router-dom'

import { logOut } from '~/core/apolloClient'
import { INVITATION_ROUTE_FORM, useNavigate } from '~/core/router'
import { useIsAuthenticated } from '~/hooks/auth/useIsAuthenticated'

const InvitationInit = () => {
  const { token } = useParams()
  const { isAuthenticated } = useIsAuthenticated()
  const navigate = useNavigate()
  const client = useApolloClient()

  useEffect(() => {
    const triggerLogout = async () => {
      await logOut(client, true)
    }

    triggerLogout()

    // We first logout the user and then redirect to the invitation form
    !isAuthenticated && navigate(generatePath(INVITATION_ROUTE_FORM, { token: token as string }))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isAuthenticated])

  return <Outlet />
}

export default InvitationInit
