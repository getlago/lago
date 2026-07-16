import { gql } from '@apollo/client'
import { revalidateLogic } from '@tanstack/react-form'
import { useState } from 'react'

import { ButtonLink } from '~/components/designSystem/ButtonLink'
import { hasDefinedGQLError } from '~/core/apolloClient'
import { LOGIN_ROUTE } from '~/core/router'
import { LagoApiError, useCreatePasswordResetMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'
import { Card, Page, StyledLogo, Subtitle, Title } from '~/styles/auth'

import {
  forgotPasswordDefaultValues,
  forgotPasswordValidationSchema,
} from './forgotPasswordForm/validationSchema'

export const FORGOT_PASSWORD_SUBMIT_BUTTON_TEST_ID = 'forgot-password-submit-button'
export const FORGOT_PASSWORD_BACK_TO_LOGIN_TEST_ID = 'forgot-password-back-to-login'

gql`
  mutation createPasswordReset($input: CreatePasswordResetInput!) {
    createPasswordReset(input: $input) {
      id
    }
  }
`

const ForgotPassword = () => {
  const { translate } = useInternationalization()
  const [hasSubmitted, setHasSubmitted] = useState<boolean>(false)
  const [createPasswordReset] = useCreatePasswordResetMutation({
    context: { silentErrorCodes: [LagoApiError.NotFound] },
    onCompleted(data) {
      if (data && data.createPasswordReset) {
        setHasSubmitted(true)
      }
    },
  })

  const form = useAppForm({
    defaultValues: forgotPasswordDefaultValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: forgotPasswordValidationSchema,
    },
    onSubmit: async ({ value, formApi }) => {
      const answer = await createPasswordReset({
        variables: {
          input: {
            email: value.email,
          },
        },
      })

      const { errors } = answer

      if (hasDefinedGQLError('NotFound', errors)) {
        formApi.setErrorMap({
          onDynamic: {
            fields: {
              email: {
                message: translate('text_642707b0da1753a9bb6672ac'),
                path: ['email'],
              },
            },
          },
        })
      }
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
        {hasSubmitted ? (
          <>
            <Title>{translate('text_642707b0da1753a9bb66728e')}</Title>
            <Subtitle>{translate('text_642707b0da1753a9bb667298')}</Subtitle>
            <ButtonLink
              type="button"
              to={LOGIN_ROUTE}
              data-test={FORGOT_PASSWORD_BACK_TO_LOGIN_TEST_ID}
              buttonProps={{ size: 'large', fullWidth: true, variant: 'secondary' }}
            >
              {translate('text_642707b0da1753a9bb6672a1')}
            </ButtonLink>
          </>
        ) : (
          <>
            <Title>{translate('text_642707b0da1753a9bb66728c')}</Title>
            <Subtitle>{translate('text_642707b0da1753a9bb667296')}</Subtitle>
            <form onSubmit={handleSubmit}>
              <form.AppField name="email">
                {(field) => (
                  <field.TextInputField
                    className="mb-8"
                    beforeChangeFormatter={['lowercase']}
                    label={translate('text_62a99ba2af7535cefacab4aa')}
                    placeholder={translate('text_62a99ba2af7535cefacab4bf')}
                    // eslint-disable-next-line jsx-a11y/no-autofocus
                    autoFocus
                  />
                )}
              </form.AppField>

              <form.AppForm>
                <form.SubmitButton
                  dataTest={FORGOT_PASSWORD_SUBMIT_BUTTON_TEST_ID}
                  size="large"
                  fullWidth
                >
                  {translate('text_642707b0da1753a9bb6672b2')}
                </form.SubmitButton>
              </form.AppForm>
            </form>
          </>
        )}
      </Card>
    </Page>
  )
}

export default ForgotPassword
