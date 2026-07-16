import { gql, useApolloClient } from '@apollo/client'
import { Icon } from 'lago-design-system'
import { useEffect, useRef } from 'react'
// eslint-disable-next-line lago/no-direct-rrd-nav-import -- Auth callback renders outside /:organizationSlug; the slug wrapper would be incorrect here.
import { generatePath, useNavigate, useSearchParams } from 'react-router-dom'

import { GoogleAuthModeEnum } from '~/components/auth/GoogleAuthButton'
import { hasDefinedGQLError, LagoGQLError, onLogIn } from '~/core/apolloClient'
import { INVITATION_ROUTE_FORM, LOGIN_ROUTE, SIGN_UP_ROUTE } from '~/core/router'
import { setItemFromLS } from '~/core/utils/localStorage'
import { REDIRECT_AFTER_LOGIN_LS_KEY } from '~/core/utils/localStorageKeys'
import { LagoApiError, useGoogleLoginUserMutation } from '~/generated/graphql'

gql`
  mutation googleLoginUser($input: GoogleLoginUserInput!) {
    googleLoginUser(input: $input) {
      token
    }
  }
`

const GoogleAuthCallback = () => {
  const navigate = useNavigate()
  const client = useApolloClient()
  const hasRun = useRef(false)
  const [googleLoginUser] = useGoogleLoginUserMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
  })

  const [searchParams] = useSearchParams()
  const code = searchParams.get('code') || ''
  const state = JSON.parse(searchParams.get('state') || '{}')
  const invitationToken = state.invitationToken || ''
  const mode = state.mode as GoogleAuthModeEnum
  const redirectPath = state.redirectPath

  useEffect(() => {
    // Guard against React StrictMode double-execution.
    // The OAuth code can only be consumed once by the backend.
    if (hasRun.current) return
    hasRun.current = true

    if (!code) {
      navigate(LOGIN_ROUTE)
      return
    }

    const googleCallback = async () => {
      if (mode === 'signup') {
        return navigate({
          pathname: SIGN_UP_ROUTE,
          search: `?code=${code}`,
        })
      }

      if (mode === 'invite') {
        return navigate({
          pathname: generatePath(INVITATION_ROUTE_FORM, { token: invitationToken as string }),
          search: `?code=${code}`,
        })
      }

      if (mode !== 'login') {
        return
      }

      const res = await googleLoginUser({
        variables: { input: { code } },
      })

      if (res.errors) {
        if (hasDefinedGQLError('LoginMethodNotAuthorized', res.errors)) {
          return navigate({
            pathname: LOGIN_ROUTE,
            search: `?lago_error_code=${LagoApiError.GoogleLoginMethodNotAuthorized}`,
          })
        }

        return navigate({
          pathname: LOGIN_ROUTE,
          search: `?lago_error_code=${
            (res.errors[0].extensions as LagoGQLError['extensions'])?.details.base[0]
          }`,
        })
      }

      if (!res.data?.googleLoginUser) {
        return
      }

      // Store redirect path in localStorage before onLogIn to survive
      // the race condition with the onlyPublic route guard. When onLogIn sets
      // authTokenVar, the guard may redirect to HOME before this callback
      // can navigate — localStorage ensures Home.tsx can still find the path.
      // Home.tsx is the SINGLE point of cleanup for REDIRECT_AFTER_LOGIN_LS_KEY.
      if (redirectPath) {
        setItemFromLS(REDIRECT_AFTER_LOGIN_LS_KEY, redirectPath)
      }

      await onLogIn(client, res.data?.googleLoginUser?.token)
    }

    googleCallback()

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return (
    <div className="m-auto flex h-40 w-full items-center justify-center">
      <Icon name="processing" color="info" size="large" animation="spin" />
    </div>
  )
}

export default GoogleAuthCallback
