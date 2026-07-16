import { gql, useApolloClient } from '@apollo/client'
import _findKey from 'lodash/findKey'
import { useEffect, useMemo, useState } from 'react'
import { useParams } from 'react-router-dom'
import { object, string } from 'yup'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { TextInput } from '~/components/form'
import { addToast, onLogIn } from '~/core/apolloClient'
import {
  LagoApiError,
  useGetPasswordResetQuery,
  useResetPasswordMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useShortcuts } from '~/hooks/ui/useShortcuts'
import { theme } from '~/styles'
import { Card, Page, StyledLogo, Subtitle, Title } from '~/styles/auth'

gql`
  query getPasswordReset($token: String!) {
    passwordReset(token: $token) {
      id
      user {
        id
        email
      }
    }
  }

  mutation resetPassword($input: ResetPasswordInput!) {
    resetPassword(input: $input) {
      token
    }
  }
`

type Fields = { password: string }
enum FORM_ERRORS {
  REQUIRED_PASSWORD = 'requiredPassword',
  LOWERCASE = 'text_63246f875e2228ab7b63dcfa',
  UPPERCASE = 'text_63246f875e2228ab7b63dd11',
  NUMBER = 'text_63246f875e2228ab7b63dd15',
  SPECIAL = 'text_63246f875e2228ab7b63dd17',
  MIN = 'text_63246f875e2228ab7b63dd1a',
}

const PASSWORD_VALIDATION = [
  FORM_ERRORS.LOWERCASE,
  FORM_ERRORS.SPECIAL,
  FORM_ERRORS.UPPERCASE,
  FORM_ERRORS.MIN,
  FORM_ERRORS.NUMBER,
]

const ResetPassword = () => {
  const { translate } = useInternationalization()
  const { token } = useParams()
  const client = useApolloClient()

  const { data, loading, error } = useGetPasswordResetQuery({
    context: { silentErrorCodes: [LagoApiError.NotFound] },
    notifyOnNetworkStatusChange: true,
    fetchPolicy: 'network-only',
    nextFetchPolicy: 'network-only',
    skip: !token,
    variables: { token: token || '' },
  })

  const [resetPassword] = useResetPasswordMutation({
    onCompleted: async (res) => {
      if (!!res?.resetPassword) {
        await onLogIn(client, res?.resetPassword.token)
      } else {
        addToast({
          severity: 'danger',
          translateKey: 'text_62b31e1f6a5b8b1b745ece48',
        })
      }
    },
  })
  const email = data?.passwordReset?.user?.email || ''

  const [formFields, setFormFields] = useState<Fields>({
    password: '',
  })
  const [errors, setErrors] = useState<FORM_ERRORS[]>([])
  const validationSchema = useMemo(
    () =>
      object().shape({
        password: string()
          .min(8, FORM_ERRORS.MIN)
          .matches(RegExp('(.*[a-z].*)'), FORM_ERRORS.LOWERCASE)
          .matches(RegExp('(.*[A-Z].*)'), FORM_ERRORS.UPPERCASE)
          .matches(RegExp('(.*\\d.*)'), FORM_ERRORS.NUMBER)
          .matches(RegExp('[/_!@#$%^&*(),.?":{}|<>/-]'), FORM_ERRORS.SPECIAL),
      }),
    [],
  )
  const onResetPassword = async () => {
    const { password } = formFields

    await resetPassword({
      variables: {
        input: {
          token: token || '',
          newPassword: password,
        },
      },
    })
  }

  useEffect(() => {
    validationSchema
      .validate(formFields, { abortEarly: false })
      .catch((err) => err)
      .then((param) => {
        if (!!param?.errors && param.errors.length > 0) {
          setErrors(param.errors)
        } else {
          setErrors([])
        }
      })
  }, [formFields, validationSchema])

  useShortcuts([
    {
      keys: ['Enter'],
      disabled: errors.length > 0,
      action: onResetPassword,
    },
  ])

  return (
    <Page>
      <Card>
        <StyledLogo height={24} />

        {!!loading && !error && (
          <>
            <Skeleton variant="text" className="mb-8 w-52" />
            <Skeleton variant="text" className="mb-4 w-110" />
            <Skeleton variant="text" className="w-76" />
          </>
        )}
        {!!error && !loading && (
          <>
            <Title>{translate('text_642707b0da1753a9bb667292')}</Title>
            <Subtitle noMargins>{translate('text_642707b0da1753a9bb66729c')}</Subtitle>
          </>
        )}
        {!loading && !error && (
          <>
            <Title>{translate('text_642707b0da1753a9bb667290')}</Title>
            <Subtitle>{translate('text_642707b0da1753a9bb66729a')}</Subtitle>

            <form>
              <TextInput
                disabled
                className="mb-4"
                name="email"
                beforeChangeFormatter={['lowercase']}
                label={translate('text_63246f875e2228ab7b63dcdc')}
                value={email}
              />

              <div className="mb-8">
                <TextInput
                  name="password"
                  value={formFields.password}
                  password
                  onChange={(value) => setFormFields((prev) => ({ ...prev, password: value }))}
                  label={translate('text_63246f875e2228ab7b63dce9')}
                  placeholder={translate('text_63246f875e2228ab7b63dcf0')}
                />
                <div className="mt-4 flex max-h-124 flex-wrap overflow-hidden transition-all duration-250">
                  {errors.some((err) => PASSWORD_VALIDATION.includes(err)) ? (
                    PASSWORD_VALIDATION.map((err) => {
                      const isErrored = errors.includes(err)

                      return (
                        <div
                          className="mb-3 flex h-5 w-1/2 flex-row items-center gap-3"
                          key={err}
                          data-test={
                            isErrored ? _findKey(FORM_ERRORS, (v) => v === err) : undefined
                          }
                        >
                          <svg height={8} width={8}>
                            <circle
                              cx="4"
                              cy="4"
                              r="4"
                              fill={
                                isErrored ? theme.palette.primary.main : theme.palette.grey[500]
                              }
                            />
                          </svg>
                          <Typography
                            variant="caption"
                            color={isErrored ? 'textSecondary' : 'textPrimary'}
                          >
                            {translate(err)}
                          </Typography>
                        </div>
                      )
                    })
                  ) : (
                    <Alert className="mb-3 w-full" type="success" data-test="success">
                      {translate('text_63246f875e2228ab7b63dd02')}
                    </Alert>
                  )}
                </div>
              </div>

              <Button
                className="mb-8"
                data-test="submit-button"
                disabled={errors.length > 0}
                fullWidth
                size="large"
                onClick={onResetPassword}
              >
                {translate('text_642707b0da1753a9bb6672c4')}
              </Button>
            </form>
          </>
        )}
      </Card>
    </Page>
  )
}

export default ResetPassword
