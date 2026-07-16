import { gql, useApolloClient } from '@apollo/client'
import Stack from '@mui/material/Stack'
import { useFormik } from 'formik'
import { useEffect, useState } from 'react'
import { generatePath, useSearchParams } from 'react-router-dom'
import { object, string } from 'yup'

import GoogleAuthButton from '~/components/auth/GoogleAuthButton'
import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { TextInputField } from '~/components/form'
import { envGlobalVar, hasDefinedGQLError, onLogIn } from '~/core/apolloClient'
import { authenticationMethodsMapping } from '~/core/constants/authenticationMethodsMapping'
import {
  FORGOT_PASSWORD_ROUTE,
  Link,
  LOGIN_OKTA,
  SIGN_UP_ROUTE,
  useLocation,
  useNavigate,
} from '~/core/router'
import { AuthenticationMethodsEnum, LagoApiError, useLoginUserMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useShortcuts } from '~/hooks/ui/useShortcuts'
import { useDeveloperTool } from '~/hooks/useDeveloperTool'
import { useIframeConfig } from '~/hooks/useIframeConfig'
import { Card, Page, StyledLogo } from '~/styles/auth'

const { disableSignUp } = envGlobalVar()

gql`
  mutation loginUser($input: LoginUserInput!) {
    loginUser(input: $input) {
      token
    }
  }
`

const Login = () => {
  const { translate } = useInternationalization()
  const { isRunningInSalesForceIframe, isRunningInIframeContext } = useIframeConfig()
  const location = useLocation()
  const navigate = useNavigate()
  const { closePanel: closeDevTool } = useDeveloperTool()
  const client = useApolloClient()
  const [authMethodError, setAuthMethodError] = useState<AuthenticationMethodsEnum>()
  const [searchParams] = useSearchParams()

  const lagoErrorCode = searchParams.get('lago_error_code')

  useEffect(() => {
    // Okta login method not authorized
    // Google login method is handled in GoogleAuthButton
    if (lagoErrorCode === LagoApiError.OktaLoginMethodNotAuthorized) {
      setAuthMethodError(AuthenticationMethodsEnum.Okta)
    }
  }, [lagoErrorCode])

  useEffect(() => {
    // In case the devtools are open, close it
    closeDevTool()

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const [loginUser, { error: loginError }] = useLoginUserMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted: async (res) => {
      if (!!res?.loginUser) {
        await onLogIn(client, res.loginUser.token)
      }
    },
    onError(error) {
      if (hasDefinedGQLError('LoginMethodNotAuthorized', error, 'emailPassword')) {
        setAuthMethodError(AuthenticationMethodsEnum.EmailPassword)
      }
    },
    fetchPolicy: 'network-only',
  })

  const formikProps = useFormik({
    initialValues: {
      email: '',
      password: '',
    },
    validationSchema: object().shape({
      email: string()
        .email('text_620bc4d4269a55014d493fc3')
        .required('text_620bc4d4269a55014d493f98'),
      password: string().required('text_620bc4d4269a55014d493fb3'),
    }),
    validateOnChange: false,
    validateOnBlur: false,
    onSubmit: async (values) => {
      await loginUser({
        variables: {
          input: {
            email: values.email,
            password: values.password,
          },
        },
      })
    },
  })

  useShortcuts([
    {
      keys: ['Enter'],
      action: formikProps.submitForm,
    },
  ])

  return (
    <Page>
      <Card>
        <StyledLogo height={24} />

        <Stack spacing={8}>
          <Stack spacing={3}>
            <Typography variant="headline">{translate('text_620bc4d4269a55014d493f08')}</Typography>
            <Typography>{translate('text_620bc4d4269a55014d493f81')}</Typography>
          </Stack>

          {hasDefinedGQLError('IncorrectLoginOrPassword', loginError) && (
            <Alert data-test="incorrect-login-or-password-alert" type="danger">
              {translate('text_620bc4d4269a55014d493fb7')}
            </Alert>
          )}

          {authMethodError && (
            <Alert data-test="login-method-not-authorized-alert" type="danger">
              {translate('text_17521583805554mlsol8fld6', {
                method: translate(authenticationMethodsMapping[authMethodError]),
              })}
            </Alert>
          )}

          {!isRunningInSalesForceIframe && !isRunningInIframeContext && (
            <>
              <Stack spacing={4}>
                <GoogleAuthButton
                  mode="login"
                  label={translate('text_660bf95c75dd928ced0ecb31')}
                  hideAlert={!!loginError}
                />
                <Button
                  fullWidth
                  startIcon="okta"
                  size="large"
                  variant="tertiary"
                  onClick={() => navigate(LOGIN_OKTA, { state: location.state })}
                >
                  {translate('text_664c90c9b2b6c2012aa50bce')}
                </Button>
              </Stack>

              <div className="flex items-center justify-center gap-4 before:flex-1 before:border before:border-grey-300 before:content-[''] after:flex-1 after:border after:border-grey-300 after:content-['']">
                <Typography variant="captionHl" color="grey500">
                  {translate('text_6303351deffd2a0d70498675').toUpperCase()}
                </Typography>
              </div>
            </>
          )}

          <div className="flex flex-col gap-4">
            <TextInputField
              // eslint-disable-next-line jsx-a11y/no-autofocus
              autoFocus
              name="email"
              beforeChangeFormatter={['lowercase']}
              formikProps={formikProps}
              label={translate('text_62ab2d0396dd6b0361614d60')}
              placeholder={translate('text_62a99ba2af7535cefacab4bf')}
            />

            <div className="relative">
              <TextInputField
                name="password"
                formikProps={formikProps}
                password
                label={translate('text_620bc4d4269a55014d493f32')}
                placeholder={translate('text_620bc4d4269a55014d493f5b')}
              />
              <Typography className="absolute right-0 top-0" variant="caption">
                <Link to={generatePath(FORGOT_PASSWORD_ROUTE)}>
                  {translate('text_642707b0da1753a9bb6672b5')}
                </Link>
              </Typography>
            </div>
          </div>

          <Button data-test="submit" fullWidth size="large" onClick={formikProps.submitForm}>
            {translate('text_620bc4d4269a55014d493f6d')}
          </Button>

          {!disableSignUp && !isRunningInSalesForceIframe && !isRunningInIframeContext && (
            <Typography
              className="mx-auto text-center"
              variant="caption"
              html={translate('text_62c84d0029355c83db4dd186', {
                linkSignUp: SIGN_UP_ROUTE,
              })}
            />
          )}
        </Stack>
      </Card>
    </Page>
  )
}

export default Login
