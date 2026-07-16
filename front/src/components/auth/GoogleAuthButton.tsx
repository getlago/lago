import { gql } from '@apollo/client'
import Stack from '@mui/material/Stack'
import { useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { hasDefinedGQLError } from '~/core/apolloClient'
import { DOCUMENTATION_ENV_VARS } from '~/core/constants/externalUrls'
import { useLocation } from '~/core/router'
import { addValuesToUrlState } from '~/core/utils/urlUtils'
import { LagoApiError, useGetGoogleAuthUrlLazyQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

export type GoogleAuthModeEnum = 'login' | 'signup' | 'invite'

const getErrorKey = (errorCode: GoogleErrorCodes): string => {
  // Note: some error code are underscrored as they can come from the google callback page via url parameter
  switch (errorCode) {
    case 'invalid_google_token':
    case 'invalid_google_code':
    case 'GoogleAuthMissingSetup':
      return 'text_660bf95c75dd928ced0ecb25'
    case 'user_does_not_exist':
      return 'text_660bfaa2cbc95800a63f48b1'
    case 'google_login_method_not_authorized':
      return 'text_17521583805554mlsol8fld6'
    default:
      return 'text_62b31e1f6a5b8b1b745ece48'
  }
}

gql`
  query getGoogleAuthUrl {
    googleAuthUrl {
      url
    }
  }
`

const GoogleErrorCodes = [
  'GoogleAuthMissingSetup',
  'invalid_google_code',
  'invalid_google_token',
  'user_does_not_exist',
  'google_login_method_not_authorized',
] as const

type GoogleErrorCodes = (typeof GoogleErrorCodes)[number]

type BasicGoogleAuthButtonProps = {
  mode: GoogleAuthModeEnum
  label: string
  invitationToken?: string
  hideAlert?: boolean
}

const GoogleAuthButton = ({
  invitationToken,
  hideAlert,
  label,
  mode,
}: BasicGoogleAuthButtonProps) => {
  const { translate } = useInternationalization()
  const [searchParams] = useSearchParams()

  const [errorCode, setErrorCode] = useState<GoogleErrorCodes>()
  const lagoErrorCode = searchParams.get('lago_error_code') || ''

  const [getGoogleUrl] = useGetGoogleAuthUrlLazyQuery({
    fetchPolicy: 'network-only',
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
  })

  useEffect(() => {
    if (lagoErrorCode && GoogleErrorCodes.includes(lagoErrorCode as GoogleErrorCodes)) {
      // Set the error code to be displayed
      setErrorCode(lagoErrorCode as GoogleErrorCodes)
      // Remove the error code from the URL, so it disappears on page reload
      history.replaceState({}, '', window.location.pathname)
    }

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const location = useLocation()

  const previousLocation = location.state?.from?.pathname

  return (
    <Stack spacing={8}>
      {!!errorCode && !hideAlert && (
        <Alert type="danger" data-test="google-auth-button-error-alert">
          <Typography
            color="textSecondary"
            html={
              !!getErrorKey(errorCode)
                ? translate(getErrorKey(errorCode), {
                    href: DOCUMENTATION_ENV_VARS,
                    method: translate('text_1752158380555upqjf6cxtq9'),
                  })
                : undefined
            }
          />
        </Alert>
      )}

      <Button
        fullWidth
        startIcon="google"
        size="large"
        variant="tertiary"
        onClick={async () => {
          const { data, errors } = await getGoogleUrl()

          // Note: keep underscore notation for some error codes
          if (hasDefinedGQLError('GoogleAuthMissingSetup', errors)) {
            return setErrorCode('GoogleAuthMissingSetup')
          } else if (hasDefinedGQLError('InvalidGoogleCode', errors)) {
            return setErrorCode('invalid_google_code')
          } else if (hasDefinedGQLError('InvalidGoogleToken', errors)) {
            return setErrorCode('invalid_google_token')
          } else if (hasDefinedGQLError('UserDoesNotExist', errors)) {
            return setErrorCode('user_does_not_exist')
          } else if (hasDefinedGQLError('LoginMethodNotAuthorized', errors)) {
            return setErrorCode('google_login_method_not_authorized')
          }

          if (data?.googleAuthUrl?.url) {
            window.location.href = addValuesToUrlState({
              url: data.googleAuthUrl.url,
              stateType: 'object',
              values: {
                mode,
                redirectPath: previousLocation,
                ...(!!invitationToken && { invitationToken }),
              },
            })
          }
        }}
      >
        {label}
      </Button>
    </Stack>
  )
}

export default GoogleAuthButton
