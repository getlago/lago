import { gql } from '@apollo/client'
import Stack from '@mui/material/Stack'
import { revalidateLogic } from '@tanstack/react-form'
import { useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'

import { Alert } from '~/components/designSystem/Alert'
import { Typography } from '~/components/designSystem/Typography'
import { hasDefinedGQLError } from '~/core/apolloClient'
import { LOGIN_ROUTE, useLocation } from '~/core/router'
import { setItemFromLS } from '~/core/utils/localStorage'
import { REDIRECT_AFTER_LOGIN_LS_KEY } from '~/core/utils/localStorageKeys'
import { addValuesToUrlState } from '~/core/utils/urlUtils'
import { LagoApiError, useFetchOktaAuthorizeUrlMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'
import { Card, Page, StyledLogo } from '~/styles/auth'

import { loginOktaDefaultValues, loginOktaValidationSchema } from './loginOktaForm/validationSchema'

const getErrorKey = (code: LagoApiError): string => {
  switch (code) {
    case LagoApiError.OktaUserinfoError:
      return 'text_664c98989d08a3f733357f73'
    case LagoApiError.DomainNotConfigured:
      return 'text_664c90c9b2b6c2012aa50bd6'
    default:
      return 'text_62b31e1f6a5b8b1b745ece48'
  }
}

gql`
  mutation fetchOktaAuthorizeUrl($input: OktaAuthorizeInput!) {
    oktaAuthorize(input: $input) {
      url
    }
  }
`

const LoginOkta = () => {
  const { translate } = useInternationalization()
  const location = useLocation()
  const [searchParams] = useSearchParams()
  const previousLocation = (location.state as { from?: Location } | null)?.from?.pathname
  const [errorAlert, setErrorAlert] = useState<LagoApiError>()

  const lagoErrorCode = searchParams.get('lago_error_code')

  const [fetchOktaAuthorizeUrl] = useFetchOktaAuthorizeUrlMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    fetchPolicy: 'network-only',
  })

  useEffect(() => {
    if (lagoErrorCode) {
      setErrorAlert(lagoErrorCode as LagoApiError)

      // Remove the error code from the URL, so it disappears on page reload
      history.replaceState({}, '', window.location.pathname)
    }

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const form = useAppForm({
    defaultValues: loginOktaDefaultValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: loginOktaValidationSchema,
    },
    onSubmit: async ({ value, formApi }) => {
      const answer = await fetchOktaAuthorizeUrl({
        variables: {
          input: {
            email: value.email,
          },
        },
      })

      const { errors, data } = answer

      if (hasDefinedGQLError('DomainNotConfigured', errors)) {
        formApi.setErrorMap({
          onDynamic: {
            fields: {
              email: {
                message: translate(getErrorKey(LagoApiError.DomainNotConfigured)),
                path: ['email'],
              },
            },
          },
        })
        return
      }

      if (errors?.length) {
        setErrorAlert(LagoApiError.UnprocessableEntity)
        return
      }

      if (!data?.oktaAuthorize?.url) return

      setErrorAlert(undefined)

      if (previousLocation) {
        setItemFromLS(REDIRECT_AFTER_LOGIN_LS_KEY, previousLocation)
      }

      window.location.href = addValuesToUrlState({
        url: data.oktaAuthorize.url,
        stateType: 'string',
        values: {},
      })
    },
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    form.handleSubmit()
  }

  return (
    <Page>
      <Card>
        <StyledLogo height={24} />

        <form onSubmit={handleSubmit}>
          <Stack spacing={8}>
            <Stack spacing={3}>
              <Typography variant="headline">
                {translate('text_664c90c9b2b6c2012aa50bce')}
              </Typography>
              <Typography>{translate('text_664c90c9b2b6c2012aa50bd0')}</Typography>
            </Stack>

            {!!errorAlert && (
              <Alert type="danger" data-test="login-okta-error-alert">
                <Typography color="textSecondary">{translate(getErrorKey(errorAlert))}</Typography>
              </Alert>
            )}

            <form.AppField name="email">
              {(field) => (
                <field.TextInputField
                  // eslint-disable-next-line jsx-a11y/no-autofocus
                  autoFocus
                  beforeChangeFormatter={['lowercase']}
                  label={translate('text_62ab2d0396dd6b0361614d60')}
                  placeholder={translate('text_62a99ba2af7535cefacab4bf')}
                />
              )}
            </form.AppField>

            <form.AppForm>
              <form.SubmitButton dataTest="submit" fullWidth size="large">
                {translate('text_620bc4d4269a55014d493f6d')}
              </form.SubmitButton>
            </form.AppForm>

            <Typography
              className="mx-auto text-center"
              variant="caption"
              html={translate('text_664c90c9b2b6c2012aa50bda', {
                linkLogin: LOGIN_ROUTE,
              })}
            />
          </Stack>
        </form>
      </Card>
    </Page>
  )
}

export default LoginOkta
