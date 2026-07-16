import { gql, useApolloClient } from '@apollo/client'
import Stack from '@mui/material/Stack'
import { revalidateLogic, useStore } from '@tanstack/react-form'
import { useEffect, useMemo } from 'react'
import { useParams, useSearchParams } from 'react-router-dom'

import GoogleAuthButton from '~/components/auth/GoogleAuthButton'
import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { PasswordValidationHints } from '~/components/form/PasswordValidationHints/PasswordValidationHints'
import { TextInput } from '~/components/form/TextInput'
import { hasDefinedGQLError, onLogIn } from '~/core/apolloClient'
import { DOCUMENTATION_ENV_VARS } from '~/core/constants/externalUrls'
import { LOGIN_ROUTE } from '~/core/router'
import { addValuesToUrlState } from '~/core/utils/urlUtils'
import { PASSWORD_VALIDATION_ERRORS } from '~/formValidation/zodCustoms'
import {
  CurrentUserFragmentDoc,
  LagoApiError,
  useAcceptInviteMutation,
  useFetchOktaAuthorizeUrlMutation,
  useGetinviteQuery,
  useGoogleAcceptInviteMutation,
  useOktaAcceptInviteMutation,
} from '~/generated/graphql'
import { useIsAuthenticated } from '~/hooks/auth/useIsAuthenticated'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'
import { usePasswordValidation } from '~/hooks/forms/usePasswordValidation'
import { Card, Page, StyledLogo, Subtitle, Title } from '~/styles/auth'

import {
  invitationDefaultValues,
  invitationValidationSchema,
} from './invitationForm/validationSchema'

export const INVITATION_FORM_ID = 'invitation-form'
export const INVITATION_ERROR_ALERT_TEST_ID = 'invitation-error-alert'
export const INVITATION_SUBMIT_BUTTON_TEST_ID = 'submit-button'

gql`
  query getinvite($token: String!) {
    invite(token: $token) {
      id
      email
      organization {
        id
        name
      }
    }
  }

  mutation acceptInvite($input: AcceptInviteInput!) {
    acceptInvite(input: $input) {
      token
    }
  }

  mutation googleAcceptInvite($input: GoogleAcceptInviteInput!) {
    googleAcceptInvite(input: $input) {
      token
    }
  }

  mutation fetchOktaAuthorizeUrl($input: OktaAuthorizeInput!) {
    oktaAuthorize(input: $input) {
      url
    }
  }

  mutation oktaAcceptInvite($input: OktaAcceptInviteInput!) {
    oktaAcceptInvite(input: $input) {
      token
    }
  }

  ${CurrentUserFragmentDoc}
`

const Invitation = () => {
  const { isAuthenticated } = useIsAuthenticated()
  const { translate } = useInternationalization()
  const { token } = useParams()
  const client = useApolloClient()
  const [searchParams] = useSearchParams()

  const googleCode = searchParams.get('code') || ''
  const oktaCode = searchParams.get('oktaCode') || ''
  const oktaState = searchParams.get('oktaState') || ''

  const { data, error, loading } = useGetinviteQuery({
    context: { silentErrorCodes: [LagoApiError.InviteNotFound, LagoApiError.NotFound] },
    variables: { token: token || '' },
    skip: !token || isAuthenticated, // We need to skip when authenticated to prevent an error flash on the form after submit
  })
  const email = data?.invite?.email

  const [acceptInvite, { error: acceptInviteError, loading: acceptInviteLoading }] =
    useAcceptInviteMutation({
      context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
      onCompleted: async (res) => {
        if (!!res?.acceptInvite) {
          await onLogIn(client, res?.acceptInvite.token)
        }
      },
    })

  const [googleAcceptInvite, { error: googleAcceptInviteError }] = useGoogleAcceptInviteMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted: async (res) => {
      if (!!res?.googleAcceptInvite) {
        await onLogIn(client, res?.googleAcceptInvite.token)
      }
    },
  })

  const [
    fetchOktaAuthorizeUrl,
    { error: oktaAuthorizeUrlError, loading: oktaAuthorizeUrlLoading },
  ] = useFetchOktaAuthorizeUrlMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    fetchPolicy: 'network-only',
  })

  const [oktaAcceptInvite, { error: oktaAcceptInviteError, loading: oktaAcceptInviteLoading }] =
    useOktaAcceptInviteMutation({
      context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
      onCompleted: async (res) => {
        if (!!res?.oktaAcceptInvite) {
          await onLogIn(client, res?.oktaAcceptInvite.token)
        }
      },
    })

  const form = useAppForm({
    defaultValues: invitationDefaultValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: invitationValidationSchema,
    },
    onSubmit: async ({ value }) => {
      await acceptInvite({
        variables: {
          input: {
            token: token || '',
            email: email || '',
            password: value.password,
          },
        },
      })
    },
  })

  const password = useStore(form.store, (state) => state.values.password)
  const passwordValidation = usePasswordValidation(password)

  const onOktaLogin = async () => {
    const { data: oktaAuthorizeData } = await fetchOktaAuthorizeUrl({
      variables: {
        input: {
          email: email || '',
        },
      },
    })

    if (oktaAuthorizeData?.oktaAuthorize?.url) {
      window.location.href = addValuesToUrlState({
        url: oktaAuthorizeData.oktaAuthorize.url,
        values: {
          invitationToken: token || '',
        },
        stateType: 'string',
      })
    }
  }

  useEffect(() => {
    if (!!googleCode && !!token) {
      googleAcceptInvite({
        variables: {
          input: {
            code: googleCode,
            inviteToken: token || '',
          },
        },
      })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [googleCode, token])

  useEffect(() => {
    if (!!oktaCode && !!oktaState && !!token) {
      oktaAcceptInvite({
        variables: {
          input: {
            code: oktaCode,
            state: oktaState,
            inviteToken: token || '',
          },
        },
      })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [oktaCode, oktaState, token])

  const errorTranslation: string | undefined = useMemo(() => {
    if (
      !acceptInviteError &&
      !googleAcceptInviteError &&
      !oktaAcceptInviteError &&
      !oktaAuthorizeUrlError
    )
      return

    // If any error occur, we need to remove the code from the URL
    history.replaceState({}, '', window.location.pathname)

    if (
      hasDefinedGQLError('InvalidGoogleCode', googleAcceptInviteError) ||
      hasDefinedGQLError('InvalidGoogleToken', googleAcceptInviteError)
    ) {
      return translate('text_660bf95c75dd928ced0ecb25', {
        href: DOCUMENTATION_ENV_VARS,
      })
    }

    if (hasDefinedGQLError('InviteEmailMistmatch', googleAcceptInviteError)) {
      return translate('text_660bf95c75dd928ced0ecb2b')
    }

    if (hasDefinedGQLError('DomainNotConfigured', oktaAuthorizeUrlError)) {
      return translate('text_664c90c9b2b6c2012aa50bd1')
    }

    if (hasDefinedGQLError('OktaUserinfoError', oktaAcceptInviteError)) {
      return translate('text_664c98989d08a3f733357f73')
    }

    if (hasDefinedGQLError('LoginMethodNotAuthorized', oktaAcceptInviteError)) {
      return translate('text_17521583805554mlsol8fld6', {
        method: translate('text_664c732c264d7eed1c74fda2'),
      })
    }

    if (hasDefinedGQLError('LoginMethodNotAuthorized', googleAcceptInviteError)) {
      return translate('text_17521583805554mlsol8fld6', {
        method: translate('text_1752158380555upqjf6cxtq9'),
      })
    }

    if (hasDefinedGQLError('LoginMethodNotAuthorized', acceptInviteError)) {
      return translate('text_17521583805554mlsol8fld6', {
        method: translate('text_1752158380555c18bvtn8gd8'),
      })
    }

    return

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [acceptInviteError, googleAcceptInviteError, oktaAcceptInviteError, oktaAuthorizeUrlError])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    form.handleSubmit()
  }

  if (isAuthenticated) {
    return null
  }

  return (
    <Page>
      <Card>
        <StyledLogo height={24} />
        {(!!error || !data?.invite) && !loading && (
          <>
            <Title>{translate('text_63246f875e2228ab7b63dcf4')}</Title>
            <Subtitle noMargins>{translate('text_63246f875e2228ab7b63dcfe')}</Subtitle>
            <Button
              fullWidth
              variant="primary"
              size="large"
              onClick={() => window.location.assign(LOGIN_ROUTE)}
              className="mt-6"
            >
              {translate('text_620bc4d4269a55014d493f6d')}
            </Button>
          </>
        )}
        {!error && !!loading && (
          <>
            <Skeleton variant="text" className="mb-8 w-52" />
            <Skeleton variant="text" className="mb-4 w-110" />
            <Skeleton variant="text" className="w-76" />
          </>
        )}
        {!error && !loading && !!data?.invite && (
          <form id={INVITATION_FORM_ID} onSubmit={handleSubmit}>
            <Stack spacing={8}>
              <Stack spacing={3}>
                <Typography variant="headline">
                  {translate('text_664c90c9b2b6c2012aa50bcd', {
                    orgnisationName: data?.invite?.organization.name,
                  })}
                </Typography>
                <Typography>{translate('text_63246f875e2228ab7b63dcd4')}</Typography>
              </Stack>

              {!!errorTranslation && (
                <Alert type="danger" data-test={INVITATION_ERROR_ALERT_TEST_ID}>
                  <Typography color="inherit" html={errorTranslation} />
                </Alert>
              )}

              <Stack spacing={4}>
                <GoogleAuthButton
                  mode="invite"
                  invitationToken={token || ''}
                  label={translate('text_664c90c9b2b6c2012aa50bd3')}
                />

                <Button
                  fullWidth
                  startIcon="okta"
                  size="large"
                  variant="tertiary"
                  onClick={() => onOktaLogin()}
                  loading={oktaAuthorizeUrlLoading || oktaAcceptInviteLoading}
                >
                  {translate('text_664c90c9b2b6c2012aa50bd5')}
                </Button>
              </Stack>

              <div className="flex items-center justify-center gap-4 before:flex-1 before:border before:border-grey-300 before:content-[''] after:flex-1 after:border after:border-grey-300 after:content-['']">
                <Typography variant="captionHl" color="grey500">
                  {translate('text_6303351deffd2a0d70498675').toUpperCase()}
                </Typography>
              </div>

              <div className="flex flex-col gap-4">
                <TextInput
                  disabled
                  name="email"
                  beforeChangeFormatter={['lowercase']}
                  label={translate('text_63246f875e2228ab7b63dcdc')}
                  value={email}
                />

                <div>
                  <form.AppField name="password">
                    {(field) => (
                      <field.TextInputField
                        password
                        label={translate('text_63246f875e2228ab7b63dce9')}
                        placeholder={translate('text_63246f875e2228ab7b63dcf0')}
                        showOnlyErrors={[PASSWORD_VALIDATION_ERRORS.REQUIRED]}
                      />
                    )}
                  </form.AppField>
                  <PasswordValidationHints
                    password={password}
                    errors={passwordValidation.errors}
                    isValid={passwordValidation.isValid}
                    successMessage="text_63246f875e2228ab7b63dd02"
                  />
                </div>
              </div>

              <form.AppForm>
                <form.SubmitButton
                  dataTest={INVITATION_SUBMIT_BUTTON_TEST_ID}
                  fullWidth
                  size="large"
                  loading={acceptInviteLoading}
                >
                  {translate('text_63246f875e2228ab7b63dd1c')}
                </form.SubmitButton>
              </form.AppForm>
              <Typography
                variant="caption"
                html={translate('text_63246f875e2228ab7b63dd1f', { link: LOGIN_ROUTE })}
              />
            </Stack>
          </form>
        )}
      </Card>
    </Page>
  )
}

export default Invitation
