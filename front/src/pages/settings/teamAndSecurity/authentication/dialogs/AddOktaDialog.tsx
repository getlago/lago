import { gql } from '@apollo/client'
import InputAdornment from '@mui/material/InputAdornment'
import { revalidateLogic } from '@tanstack/react-form'
import { useRef } from 'react'
import { z } from 'zod'

import { useFormDialogOpeningDialog } from '~/components/dialogs/FormDialogOpeningDialog'
import { DialogResult } from '~/components/dialogs/types'
import { addToast } from '~/core/apolloClient'
import { zodDomain, zodOptionalHost } from '~/formValidation/zodCustoms'
import {
  AddOktaIntegrationDialogFragment,
  AuthenticationMethodsEnum,
  CreateOktaIntegrationInput,
  DeleteOktaIntegrationDialogFragmentDoc,
  useCreateOktaIntegrationMutation,
  useDestroyIntegrationMutation,
  useUpdateOktaIntegrationMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

gql`
  fragment AddOktaIntegrationDialog on OktaIntegration {
    id
    domain
    clientId
    clientSecret
    organizationName
    host
    ...DeleteOktaIntegrationDialog
  }

  mutation createOktaIntegration($input: CreateOktaIntegrationInput!) {
    createOktaIntegration(input: $input) {
      id
    }
  }

  mutation updateOktaIntegration($input: UpdateOktaIntegrationInput!) {
    updateOktaIntegration(input: $input) {
      id
    }
  }

  ${DeleteOktaIntegrationDialogFragmentDoc}
`

const ADD_OKTA_FORM_ID = 'form-add-okta-integration'

export const OKTA_INTEGRATION_SUBMIT_BTN = 'add-okta-dialog-submit-button'

type OpenAddOktaDialogData = {
  integration?: AddOktaIntegrationDialogFragment
  callback?: (id: string) => void
  deleteCallback?: () => void
}

const defaultFormValues: CreateOktaIntegrationInput = {
  domain: '',
  host: '',
  clientId: '',
  clientSecret: '',
  organizationName: '',
}

const validationSchema = z.object({
  domain: zodDomain,
  host: zodOptionalHost,
  clientId: z.string(),
  clientSecret: z.string(),
  organizationName: z.string(),
})

export const useAddOktaDialog = () => {
  const formDialogOpeningDialog = useFormDialogOpeningDialog()
  const { translate } = useInternationalization()
  const { organization } = useOrganizationInfos()

  const dataRef = useRef<OpenAddOktaDialogData | null>(null)
  const successRef = useRef(false)

  const [createIntegration] = useCreateOktaIntegrationMutation({
    onCompleted: (res) => {
      if (!res.createOktaIntegration) return

      successRef.current = true
      dataRef.current?.callback?.(res.createOktaIntegration.id)
      addToast({
        severity: 'success',
        message: translate('text_664c732c264d7eed1c74fde6', {
          integration: translate('text_664c732c264d7eed1c74fda2'),
        }),
      })
    },
  })

  const [updateIntegration] = useUpdateOktaIntegrationMutation({
    onCompleted: (res) => {
      if (!res.updateOktaIntegration) return

      successRef.current = true
      dataRef.current?.callback?.(res.updateOktaIntegration.id)
      addToast({
        severity: 'success',
        message: translate('text_664c732c264d7eed1c74fde8', {
          integration: translate('text_664c732c264d7eed1c74fda2'),
        }),
      })
    },
  })

  const [deleteIntegration] = useDestroyIntegrationMutation()

  const form = useAppForm({
    defaultValues: defaultFormValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: validationSchema,
    },
    onSubmit: async ({ value }) => {
      const integration = dataRef.current?.integration

      if (integration) {
        await updateIntegration({
          variables: {
            input: {
              ...value,
              id: integration.id,
            },
          },
        })
      } else {
        await createIntegration({ variables: { input: value } })
      }
    },
  })

  const handleSubmit = async (): Promise<DialogResult> => {
    successRef.current = false
    await form.handleSubmit()

    if (!successRef.current) {
      throw new Error('Submit failed')
    }

    return { reason: 'success' }
  }

  const openAddOktaDialog = (data?: OpenAddOktaDialogData) => {
    dataRef.current = data ?? null
    const integration = data?.integration
    const isEdition = !!integration

    const hasOtherAuthenticationMethodsThanOkta = organization?.authenticationMethods.some(
      (method) => method !== AuthenticationMethodsEnum.Okta,
    )

    form.reset()
    if (integration) {
      form.setFieldValue('domain', integration.domain || '')
      form.setFieldValue('host', integration.host || '')
      form.setFieldValue('clientId', integration.clientId || '')
      form.setFieldValue('clientSecret', integration.clientSecret || '')
      form.setFieldValue('organizationName', integration.organizationName || '')
    }

    formDialogOpeningDialog
      .open({
        title: translate(
          isEdition ? 'text_664c8fa719b5e7ad81c86018' : 'text_664c732c264d7eed1c74fd88',
        ),
        description: translate(
          isEdition ? 'text_664c8fa719b5e7ad81c86019' : 'text_664c732c264d7eed1c74fd8e',
        ),
        children: (
          <div className="flex flex-col gap-6 p-8">
            <form.AppField name="domain">
              {(field) => (
                <field.TextInputField
                  // eslint-disable-next-line jsx-a11y/no-autofocus
                  autoFocus
                  label={translate('text_664c732c264d7eed1c74fd94')}
                  placeholder={translate('text_664c732c264d7eed1c74fd9a')}
                  helperText={translate('text_664c732c264d7eed1c74fda0')}
                />
              )}
            </form.AppField>
            <form.AppField name="host">
              {(field) => (
                <field.TextInputField
                  label={translate('text_664c732c264d7eed1c74fdd0')}
                  placeholder={translate('text_664c732c264d7eed1c74fdd1')}
                />
              )}
            </form.AppField>
            <form.AppField name="clientId">
              {(field) => (
                <field.TextInputField
                  label={translate('text_664c732c264d7eed1c74fda6')}
                  placeholder={translate('text_664c732c264d7eed1c74fdac')}
                />
              )}
            </form.AppField>
            <form.AppField name="clientSecret">
              {(field) => (
                <field.TextInputField
                  label={translate('text_664c732c264d7eed1c74fdb2')}
                  placeholder={translate('text_664c732c264d7eed1c74fdb7')}
                />
              )}
            </form.AppField>
            <form.AppField name="organizationName">
              {(field) => (
                <field.TextInputField
                  label={translate('text_664c732c264d7eed1c74fdbb')}
                  placeholder={translate('text_664c732c264d7eed1c74fdbf')}
                  InputProps={{
                    endAdornment: (
                      <InputAdornment position="end">
                        {translate('text_664c732c264d7eed1c74fdc3')}
                      </InputAdornment>
                    ),
                  }}
                />
              )}
            </form.AppField>
          </div>
        ),
        closeOnError: false,
        mainAction: (
          <form.AppForm>
            <form.SubmitButton dataTest={OKTA_INTEGRATION_SUBMIT_BTN}>
              {translate(
                isEdition ? 'text_664c732c264d7eed1c74fdaa' : 'text_664c732c264d7eed1c74fdcb',
              )}
            </form.SubmitButton>
          </form.AppForm>
        ),
        form: {
          id: ADD_OKTA_FORM_ID,
          submit: handleSubmit,
        },
        canOpenDialog:
          isEdition && !!data?.deleteCallback && !!hasOtherAuthenticationMethodsThanOkta,
        openDialogText: translate('text_65845f35d7d69c3ab4793dad'),
        otherDialogProps: {
          title: translate('text_664c900d2d312a01546bd84b'),
          description: translate('text_664c900d2d312a01546bd84c'),
          colorVariant: 'danger',
          actionText: translate('text_645d071272418a14c1c76a81'),
          onAction: async () => {
            const result = await deleteIntegration({
              variables: {
                input: {
                  id: integration?.id ?? '',
                },
              },
              update(cache) {
                cache.evict({ id: `OktaIntegration:${integration?.id}` })
              },
            })

            if (result.data?.destroyIntegration) {
              data?.deleteCallback?.()
              addToast({
                message: translate('text_664c732c264d7eed1c74fdb4', {
                  integration: translate('text_664c732c264d7eed1c74fda2'),
                }),
                severity: 'success',
              })
            }
          },
        },
      })
      .then((response) => {
        if (response.reason === 'close' || response.reason === 'open-other-dialog') {
          form.reset()
          dataRef.current = null
        }
      })
  }

  return { openAddOktaDialog }
}
