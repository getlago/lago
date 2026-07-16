import { revalidateLogic } from '@tanstack/react-form'
import { useRef } from 'react'

import { useFormDialog } from '~/components/dialogs/FormDialog'
import EmailPreview, { BillingEntity, DocumentData } from '~/components/emails/EmailPreview'
import {
  resendEmailFormDefaultValues,
  resendEmailFormValidationSchema,
} from '~/components/emails/resendEmail/formInitialization'
import ResendEmailHeaderContent from '~/components/emails/resendEmail/ResendEmailHeaderContent'
import { addToast } from '~/core/apolloClient'
import { LagoGQLError } from '~/core/apolloClient/errorUtils'
import { BillingEntityEmailSettingsEnum, LagoApiError } from '~/generated/graphql'

import { useInternationalization } from './core/useInternationalization'
import { useAppForm } from './forms/useAppform'
import { ResendEmailFetchResult, useResendEmail } from './useResendEmail'

const SUBMIT_RESEND_EMAIL_DATA_TEST = 'submit-resend-email'
const RESEND_EMAIL_FORM_ID = 'resend-email'
const INVALID_FORM_ERROR_MESSAGE = 'form.invalid'

type Recipients =
  | {
      [x: string]: unknown
      value: string
    }[]
  | undefined

const formatRecipients = (recipients: Recipients) => {
  if (!recipients?.length) return

  return recipients.map(({ value }) => value)
}

export const useResendEmailDialog = () => {
  const formDialog = useFormDialog()
  const { resendEmail } = useResendEmail()
  const { translate } = useInternationalization()
  const successRef = useRef<ResendEmailFetchResult>(null)
  const errorRef = useRef<string | null>(null)

  const form = useAppForm({
    defaultValues: resendEmailFormDefaultValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: resendEmailFormValidationSchema,
    },
    onSubmitMeta: {} as {
      type: BillingEntityEmailSettingsEnum
      documentId: string
    },
    onSubmit: async ({ value, meta }) => {
      const result = await resendEmail({
        type: meta.type,
        documentId: meta.documentId,
        to: formatRecipients(value.to),
        cc: formatRecipients(value.cc),
        bcc: formatRecipients(value.bcc),
      })

      if (!result.success) {
        errorRef.current = (result.graphQLErrors?.[0] as LagoGQLError)?.extensions?.code || null

        return
      }

      successRef.current = result.response
    },
  })

  const handleSubmit = async ({
    type,
    documentId,
  }: {
    type: BillingEntityEmailSettingsEnum
    documentId: string
  }) => {
    successRef.current = null
    errorRef.current = null

    await form.handleSubmit({
      type,
      documentId,
    })

    // This way we can manage the validation
    if (!form.state.canSubmit) {
      throw new Error(INVALID_FORM_ERROR_MESSAGE)
    }

    if (!successRef.current || errorRef.current) {
      throw new Error(errorRef.current ?? undefined)
    }
  }

  const onError = (error: Error) => {
    if (error.message === INVALID_FORM_ERROR_MESSAGE) return

    if (error.message === LagoApiError.UnprocessableEntity) {
      addToast({
        severity: 'danger',
        message: translate('text_17712489384641tbh5v5biae'),
      })
    }
  }

  const showResendEmailDialog = ({
    subject,
    documentId,
    type,
    billingEntity,
    customerEmail,
    documentData,
  }: {
    subject: string
    documentId: string | undefined
    type: BillingEntityEmailSettingsEnum
    billingEntity: BillingEntity | undefined
    customerEmail: string | null | undefined
    documentData?: DocumentData
  }) => {
    if (!documentId) return

    if (customerEmail) {
      form.setFieldValue('to', [
        {
          value: customerEmail,
          label: customerEmail,
          customValue: true,
        },
      ])
    }

    formDialog
      .open({
        title: translate('text_1771317709944fi3nu3lw2gy'),
        headerContent: <ResendEmailHeaderContent form={form} subject={subject} />,
        children: (
          <EmailPreview
            loading={false}
            type={type}
            billingEntity={billingEntity}
            showEmailHeader={false}
            documentData={documentData}
          />
        ),
        mainAction: (
          <form.AppForm>
            <form.SubmitButton dataTest={SUBMIT_RESEND_EMAIL_DATA_TEST}>
              {translate('text_17703925321987cxf5psj6l4')}
            </form.SubmitButton>
          </form.AppForm>
        ),
        form: {
          id: RESEND_EMAIL_FORM_ID,
          submit: () =>
            handleSubmit({
              type,
              documentId,
            }),
        },
        closeOnError: false,
        onError,
      })
      .then((result) => {
        if (result.reason === 'success') {
          addToast({
            severity: 'success',
            message: translate('text_1770998960342ol0db9zrgmu'),
          })
        }
      })
  }

  return {
    showResendEmailDialog,
  }
}
