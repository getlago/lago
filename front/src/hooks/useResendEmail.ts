import { gql } from '@apollo/client'
import { GraphQLFormattedError } from 'graphql'

import {
  BillingEntityEmailSettingsEnum,
  LagoApiError,
  ResendCreditNoteEmailMutation,
  ResendInvoiceEmailMutation,
  ResendPaymentReceiptEmailMutation,
  useResendCreditNoteEmailMutation,
  useResendInvoiceEmailMutation,
  useResendPaymentReceiptEmailMutation,
} from '~/generated/graphql'

gql`
  mutation resendCreditNoteEmail($input: ResendCreditNoteEmailInput!) {
    resendCreditNoteEmail(input: $input) {
      id
    }
  }

  mutation resendInvoiceEmail($input: ResendInvoiceEmailInput!) {
    resendInvoiceEmail(input: $input) {
      id
    }
  }

  mutation resendPaymentReceiptEmail($input: ResendPaymentReceiptEmailInput!) {
    resendPaymentReceiptEmail(input: $input) {
      id
    }
  }
`

export type ResendEmailParams = {
  type: BillingEntityEmailSettingsEnum
  documentId: string
  to?: Array<string>
  cc?: Array<string>
  bcc?: Array<string>
}

export type ResendEmailFetchResult =
  | ResendCreditNoteEmailMutation
  | ResendInvoiceEmailMutation
  | ResendPaymentReceiptEmailMutation
  | null
  | undefined

export const useResendEmail = () => {
  const [resendCreditNoteEmail] = useResendCreditNoteEmailMutation()
  const [resendInvoiceEmail] = useResendInvoiceEmailMutation()
  const [resendPaymentReceiptEmail] = useResendPaymentReceiptEmailMutation()

  const resendEmailPerType = async ({ type, documentId, to, cc, bcc }: ResendEmailParams) => {
    const recipients = {
      ...(to?.length ? { to } : {}),
      ...(cc?.length ? { cc } : {}),
      ...(bcc?.length ? { bcc } : {}),
    }

    const context = { silentErrorCodes: [LagoApiError.UnprocessableEntity] }

    switch (type) {
      case BillingEntityEmailSettingsEnum.CreditNoteCreated:
        return await resendCreditNoteEmail({
          variables: {
            input: {
              id: documentId,
              ...recipients,
            },
          },
          context,
        })

      case BillingEntityEmailSettingsEnum.InvoiceFinalized:
        return await resendInvoiceEmail({
          variables: {
            input: {
              id: documentId,
              ...recipients,
            },
          },
          context,
        })

      case BillingEntityEmailSettingsEnum.PaymentReceiptCreated:
        return await resendPaymentReceiptEmail({
          variables: {
            input: {
              id: documentId,
              ...recipients,
            },
          },
          context,
        })

      default:
        throw new Error('Missing type')
    }
  }

  const resendEmail = async (
    params: ResendEmailParams,
  ): Promise<
    | {
        success: true
        response: ResendEmailFetchResult
      }
    | {
        success: false
        graphQLErrors?: readonly GraphQLFormattedError[]
      }
  > => {
    try {
      const result = await resendEmailPerType(params)

      const { errors } = result

      if (errors?.length) {
        return {
          success: false,
          graphQLErrors: errors,
        }
      }

      return {
        success: true,
        response: result.data,
      }
    } catch {
      // Network errors (500, timeout, etc.) - let them fall through as a generic failure.
      return {
        success: false,
      }
    }
  }

  return {
    resendEmail,
  }
}
