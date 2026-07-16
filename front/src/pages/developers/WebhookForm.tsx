import { gql } from '@apollo/client'
import { revalidateLogic } from '@tanstack/react-form'
import { useEffect, useMemo } from 'react'
import { useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { PageSectionTitle } from '~/components/layouts/Section'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { HOME_ROUTE } from '~/core/router'
import {
  LagoApiError,
  useCreateWebhookEndpointMutation,
  useUpdateWebhookEndpointMutation,
  WebhookEndpointSignatureAlgoEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import { useAppForm } from '~/hooks/forms/useAppform'
import { useDeveloperTool } from '~/hooks/useDeveloperTool'
import { useWebhookEndpoint } from '~/hooks/useWebhookEndpoint'
import { useWebhookEventTypes } from '~/hooks/useWebhookEventTypes'
import { FormLoadingSkeleton } from '~/styles/mainObjectsForm'

import { eventTypesToFormValues, formValuesToEventTypes } from './webhookForm/utils'
import { webhookDefaultValues, webhookValidationSchema } from './webhookForm/validationSchema'
import WebhookEventsForm from './webhookForm/WebhookEventsForm'

// Test ID constants
export const WEBHOOK_FORM_CLOSE_BUTTON_TEST_ID = 'webhook-form-close-button'
export const WEBHOOK_FORM_CANCEL_BUTTON_TEST_ID = 'webhook-form-cancel-button'
export const WEBHOOK_FORM_SUBMIT_BUTTON_TEST_ID = 'webhook-form-submit-button'
export const WEBHOOK_FORM_NAME_INPUT_TEST_ID = 'webhook-form-name-input'
export const WEBHOOK_FORM_URL_INPUT_TEST_ID = 'webhook-form-url-input'

gql`
  mutation createWebhookEndpoint($input: WebhookEndpointCreateInput!) {
    createWebhookEndpoint(input: $input) {
      id
      name
      webhookUrl
      signatureAlgo
      eventTypes
    }
  }

  mutation updateWebhookEndpoint($input: WebhookEndpointUpdateInput!) {
    updateWebhookEndpoint(input: $input) {
      id
      name
      webhookUrl
      signatureAlgo
      eventTypes
    }
  }
`

const WebhookForm = () => {
  const devtool = useDeveloperTool()
  const { webhookId = '' } = useParams()
  const { translate } = useInternationalization()
  const { goBack } = useLocationHistory()
  const { defaultEventFormValues, groups, loading: eventTypesLoading } = useWebhookEventTypes()

  const allFormKeys = useMemo(() => Object.keys(defaultEventFormValues), [defaultEventFormValues])

  useEffect(() => {
    if (devtool.panelOpen) {
      devtool.closePanel()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const { webhook, loading: webhookLoading } = useWebhookEndpoint({
    id: webhookId,
    fetchPolicy: 'no-cache',
  })

  const onClose = () => {
    goBack(HOME_ROUTE)
    devtool.openPanel()
  }

  const [createWebhook] = useCreateWebhookEndpointMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
  })

  const [updateWebhook] = useUpdateWebhookEndpointMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
  })

  const isEdition = !!webhookId

  const form = useAppForm({
    defaultValues: {
      name: webhook?.name || webhookDefaultValues.name,
      webhookUrl: webhook?.webhookUrl || webhookDefaultValues.webhookUrl,
      signatureAlgo: webhook?.signatureAlgo || webhookDefaultValues.signatureAlgo,
      webhookEvents: eventTypesToFormValues(webhook?.eventTypes, allFormKeys),
    },
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: webhookValidationSchema,
    },
    onSubmit: async ({ value, formApi }) => {
      const { webhookEvents, ...rest } = value
      const eventTypes = formValuesToEventTypes(webhookEvents)

      let res

      if (isEdition) {
        res = await updateWebhook({
          variables: {
            input: {
              id: webhookId,
              ...rest,
              eventTypes,
            },
          },
        })
      } else {
        res = await createWebhook({
          variables: {
            input: {
              ...rest,
              eventTypes,
            },
          },
        })
      }

      const { errors } = res

      if (hasDefinedGQLError('UrlIsInvalid', errors)) {
        formApi.setErrorMap({
          onDynamic: {
            fields: {
              webhookUrl: {
                message: 'text_6271200984178801ba8bdf58',
                path: ['webhookUrl'],
              },
            },
          },
        })
        return
      }

      if (hasDefinedGQLError('ValueAlreadyExist', errors)) {
        formApi.setErrorMap({
          onDynamic: {
            fields: {
              webhookUrl: {
                message: 'text_649453975a0bb300724162f6',
                path: ['webhookUrl'],
              },
            },
          },
        })
        return
      }

      if (errors) {
        addToast({
          message: translate('text_62b31e1f6a5b8b1b745ece48'),
          severity: 'danger',
        })
        return
      }

      addToast({
        message: translate(
          isEdition ? 'text_64d23b49d481ab00681c22ab' : 'text_6271200984178801ba8bdf7f',
        ),
        severity: 'success',
      })

      onClose()
    },
  })

  // Reset form when webhook data or event types are loaded (for edit mode)
  useEffect(() => {
    if (webhook && allFormKeys.length > 0) {
      form.reset({
        name: webhook.name || webhookDefaultValues.name,
        webhookUrl: webhook.webhookUrl || webhookDefaultValues.webhookUrl,
        signatureAlgo: webhook.signatureAlgo || webhookDefaultValues.signatureAlgo,
        webhookEvents: eventTypesToFormValues(webhook.eventTypes, allFormKeys),
      })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [webhook, allFormKeys])

  return (
    <CenteredPage.Wrapper>
      <CenteredPage.Header>
        {webhookLoading ? (
          <Skeleton className="w-50" variant="text" />
        ) : (
          <>
            <Typography variant="bodyHl" color="grey700" noWrap>
              {translate(
                isEdition ? 'text_64d23a81a7d807f8aa570509' : 'text_6271200984178801ba8bdec0',
              )}
            </Typography>
            <Button
              variant="quaternary"
              icon="close"
              onClick={onClose}
              data-test={WEBHOOK_FORM_CLOSE_BUTTON_TEST_ID}
            />
          </>
        )}
      </CenteredPage.Header>

      <CenteredPage.Container>
        {webhookLoading || eventTypesLoading ? (
          <FormLoadingSkeleton id="webhook" />
        ) : (
          <>
            <div className="flex flex-col gap-1">
              <Typography variant="headline" color="grey700">
                {translate(
                  isEdition ? 'text_64d23a81a7d807f8aa570509' : 'text_6271200984178801ba8bdec0',
                )}
              </Typography>
              <Typography variant="body" color="grey600">
                {translate(
                  isEdition ? 'text_64d23a81a7d807f8aa57050b' : 'text_6271200984178801ba8bdee6',
                )}
              </Typography>
            </div>

            <div>
              <PageSectionTitle
                className="mb-6"
                title={translate('text_17707227517604nyis2xn00d')}
                subtitle={translate(
                  isEdition ? 'text_1770722751760qclc7dc4kvd' : 'text_17707227517607yom6ypgxoc',
                )}
              />

              <div className="flex flex-col gap-6 border-b border-grey-300 pb-12">
                <form.AppField name="name">
                  {(field) => (
                    <field.TextInputField
                      // eslint-disable-next-line jsx-a11y/no-autofocus
                      autoFocus
                      data-test={WEBHOOK_FORM_NAME_INPUT_TEST_ID}
                      label={translate('text_1770723024044vvqxr476mvd')}
                      placeholder={translate('text_1770723024044wi5tokoswxl')}
                    />
                  )}
                </form.AppField>

                <form.AppField name="webhookUrl">
                  {(field) => (
                    <field.TextInputField
                      data-test={WEBHOOK_FORM_URL_INPUT_TEST_ID}
                      label={translate('text_6271200984178801ba8bdf22')}
                      placeholder={translate('text_6271200984178801ba8bdf36')}
                      helperText={
                        <Typography
                          variant="caption"
                          color="inherit"
                          html={translate('text_62ce85fb3fb6842020331d83')}
                        />
                      }
                    />
                  )}
                </form.AppField>

                <div>
                  <Typography className="mb-1" variant="captionHl" color="grey700">
                    {translate('text_64d23a81a7d807f8aa570513')}
                  </Typography>
                  <form.AppField name="signatureAlgo">
                    {(field) => (
                      <>
                        <field.RadioField
                          value={WebhookEndpointSignatureAlgoEnum.Hmac}
                          label={translate('text_64d23a81a7d807f8aa570519')}
                          sublabel={translate('text_64d23a81a7d807f8aa57051b')}
                        />
                        <field.RadioField
                          value={WebhookEndpointSignatureAlgoEnum.Jwt}
                          label={translate('text_64d23a81a7d807f8aa570515')}
                          sublabel={translate('text_64d23a81a7d807f8aa570517')}
                        />
                      </>
                    )}
                  </form.AppField>
                </div>
              </div>

              <div className="pt-12">
                <WebhookEventsForm
                  form={form}
                  fields="webhookEvents"
                  groups={groups}
                  isLoading={eventTypesLoading}
                />
              </div>
            </div>
          </>
        )}
      </CenteredPage.Container>

      <CenteredPage.StickyFooter>
        <Button
          variant="quaternary"
          onClick={onClose}
          data-test={WEBHOOK_FORM_CANCEL_BUTTON_TEST_ID}
        >
          {translate('text_6271200984178801ba8bdf4a')}
        </Button>
        <form.Subscribe
          selector={(state) => ({
            canSubmit: state.canSubmit,
            isSubmitting: state.isSubmitting,
          })}
        >
          {({ canSubmit, isSubmitting }) => (
            <Button
              variant="primary"
              onClick={() => form.handleSubmit()}
              disabled={!canSubmit}
              loading={isSubmitting}
              data-test={WEBHOOK_FORM_SUBMIT_BUTTON_TEST_ID}
            >
              {translate(
                isEdition ? 'text_17295436903260tlyb1gp1i7' : 'text_6271200984178801ba8bdf5e',
              )}
            </Button>
          )}
        </form.Subscribe>
      </CenteredPage.StickyFooter>
    </CenteredPage.Wrapper>
  )
}

export default WebhookForm
