import { gql, useApolloClient } from '@apollo/client'
import Stack from '@mui/material/Stack'
import { revalidateLogic, useStore } from '@tanstack/react-form'
import { useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'

import GoogleAuthButton from '~/components/auth/GoogleAuthButton'
import { Alert } from '~/components/designSystem/Alert'
import { Typography } from '~/components/designSystem/Typography'
import { PasswordValidationHints } from '~/components/form/PasswordValidationHints/PasswordValidationHints'
import { hasDefinedGQLError, onLogIn } from '~/core/apolloClient'
import { DOCUMENTATION_ENV_VARS } from '~/core/constants/externalUrls'
import { scrollToFirstInputError } from '~/core/form/scrollToFirstInputError'
import { LOGIN_ROUTE } from '~/core/router'
import { PASSWORD_VALIDATION_ERRORS } from '~/formValidation/zodCustoms'
import { LagoApiError, useGoogleRegisterMutation, useSignupMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'
import { usePasswordValidation } from '~/hooks/forms/usePasswordValidation'
import { Card, Page, StyledLogo, Subtitle, Title } from '~/styles/auth'

import {
  googleRegisterValidationSchema,
  signUpDefaultValues,
  signUpValidationSchema,
} from './signUpForm/validationSchema'
import { SIGNUP_ERROR_ALERT_TEST_ID, SIGNUP_SUBMIT_BUTTON_TEST_ID } from './signUpTestIds'

gql`
  mutation signup($input: RegisterUserInput!) {
    registerUser(input: $input) {
      token
    }
  }

  mutation googleRegister($input: GoogleRegisterUserInput!) {
    googleRegisterUser(input: $input) {
      token
    }
  }
`

const SignUp = () => {
  const client = useApolloClient()
  const [searchParams] = useSearchParams()
  const googleCode = searchParams.get('code') || ''
  const { translate } = useInternationalization()
  const [isGoogleRegister, setIsGoogleRegister] = useState<boolean>(!!googleCode)

  const [signUp, { error: signUpError }] = useSignupMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted: async (res) => {
      if (!!res?.registerUser) {
        await onLogIn(client, res.registerUser.token)
      }
    },
  })

  const [googleRegister, { error: googleRegisterError }] = useGoogleRegisterMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted: async (res) => {
      if (!!res?.googleRegisterUser) {
        await onLogIn(client, res.googleRegisterUser.token)
      }
    },
  })

  const form = useAppForm({
    defaultValues: signUpDefaultValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: isGoogleRegister ? googleRegisterValidationSchema : signUpValidationSchema,
    },
    onSubmitInvalid({ formApi }) {
      scrollToFirstInputError('sugnup-form', formApi.state.errorMap.onDynamic || {})
    },
    onSubmit: async ({ value }) => {
      if (isGoogleRegister) {
        await googleRegister({
          variables: {
            input: {
              code: googleCode,
              organizationName: value.organizationName,
            },
          },
        })
      } else {
        await signUp({
          variables: {
            input: {
              email: value.email,
              password: value.password,
              organizationName: value.organizationName,
            },
          },
        })
      }
    },
  })

  const password = useStore(form.store, (state) => state.values.password)
  const passwordValidation = usePasswordValidation(password)

  const errorTranslation: string | undefined = useMemo(() => {
    if (!googleRegisterError && !signUpError) return

    // If any error occur, we need to remove the code from the URL
    history.replaceState({}, '', window.location.pathname)
    setIsGoogleRegister(false)

    if (
      hasDefinedGQLError('UserAlreadyExists', signUpError) ||
      hasDefinedGQLError('UserAlreadyExists', googleRegisterError)
    ) {
      return translate('text_660bf95c75dd928ced0ecb1a', { href: LOGIN_ROUTE })
    }

    if (
      hasDefinedGQLError('InvalidGoogleCode', googleRegisterError) ||
      hasDefinedGQLError('InvalidGoogleToken', googleRegisterError)
    ) {
      return translate('text_660bf95c75dd928ced0ecb25', { href: DOCUMENTATION_ENV_VARS })
    }

    return

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [googleRegisterError, signUpError])

  useEffect(() => {
    if (googleCode) {
      setIsGoogleRegister(true)
    }
  }, [googleCode])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    form.handleSubmit()
  }

  return (
    <Page>
      <Card>
        <StyledLogo height={24} />

        <form id="signup-form" onSubmit={handleSubmit}>
          <Stack spacing={8}>
            <Stack spacing={3}>
              <Title>
                {translate(
                  isGoogleRegister
                    ? 'text_660bf95c75dd928ced0ecb04'
                    : 'text_620bc4d4269a55014d493f12',
                )}
              </Title>
              <Subtitle>
                {translate(
                  isGoogleRegister
                    ? 'text_660bf95c75dd928ced0ecb08'
                    : 'text_620bc4d4269a55014d493fc9',
                )}
              </Subtitle>
            </Stack>

            {!!errorTranslation && (
              <Alert type="danger" data-test={SIGNUP_ERROR_ALERT_TEST_ID}>
                <Typography color="inherit" html={errorTranslation} />
              </Alert>
            )}

            {!isGoogleRegister && (
              <>
                <GoogleAuthButton
                  mode="signup"
                  label={translate('text_660bf95c75dd928ced0ecb21')}
                />

                <div className="flex items-center justify-center gap-4 before:flex-1 before:border before:border-grey-300 before:content-[''] after:flex-1 after:border after:border-grey-300 after:content-['']">
                  <Typography variant="captionHl" color="grey500">
                    {translate('text_6303351deffd2a0d70498675').toUpperCase()}
                  </Typography>
                </div>
              </>
            )}

            <div className="flex flex-col gap-4">
              <form.AppField name="organizationName">
                {(field) => (
                  <field.TextInputField
                    label={translate('text_62a99ba2af7535cefacab49c')}
                    placeholder={translate('text_660bf95c75dd928ced0ecb33')}
                    // eslint-disable-next-line jsx-a11y/no-autofocus
                    autoFocus
                  />
                )}
              </form.AppField>

              {!isGoogleRegister && (
                <>
                  <form.AppField name="email">
                    {(field) => (
                      <field.TextInputField
                        label={translate('text_62a99ba2af7535cefacab4aa')}
                        placeholder={translate('text_62a99ba2af7535cefacab4bf')}
                        beforeChangeFormatter={['lowercase']}
                      />
                    )}
                  </form.AppField>

                  <div>
                    <form.AppField name="password">
                      {(field) => (
                        <field.TextInputField
                          password
                          label={translate('text_620bc4d4269a55014d493f53')}
                          placeholder={translate('text_620bc4d4269a55014d493f5b')}
                          showOnlyErrors={[PASSWORD_VALIDATION_ERRORS.REQUIRED]}
                        />
                      )}
                    </form.AppField>
                    <PasswordValidationHints
                      password={password}
                      errors={passwordValidation.errors}
                      isValid={passwordValidation.isValid}
                    />
                  </div>
                </>
              )}
            </div>

            <form.AppForm>
              <form.SubmitButton dataTest={SIGNUP_SUBMIT_BUTTON_TEST_ID} size="large" fullWidth>
                {translate('text_620bc4d4269a55014d493fb5')}
              </form.SubmitButton>
            </form.AppForm>

            <Typography
              variant="caption"
              html={translate('text_620bc4d4269a55014d493fd4', { link: LOGIN_ROUTE })}
            />
          </Stack>
        </form>
      </Card>
    </Page>
  )
}

export default SignUp
