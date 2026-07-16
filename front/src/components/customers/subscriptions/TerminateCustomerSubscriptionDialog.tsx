import { gql } from '@apollo/client'
import { useEffect, useMemo, useRef } from 'react'

import { hasOffsettableAmount, hasRefundableAmount } from '~/components/creditNote/utils'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { useFormDialog } from '~/components/dialogs/FormDialog'
import { DialogResult } from '~/components/dialogs/types'
import { addToast } from '~/core/apolloClient'
import {
  InvoiceTypeEnum,
  OnTerminationCreditNoteEnum,
  OnTerminationInvoiceEnum,
  StatusTypeEnum,
  TerminateSubscriptionInput,
  useGetInvoicesForTerminationQuery,
  useTerminateCustomerSubscriptionMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm, withForm } from '~/hooks/forms/useAppform'

gql`
  mutation terminateCustomerSubscription($input: TerminateSubscriptionInput!) {
    terminateSubscription(input: $input) {
      id
      status
      terminatedAt
      customer {
        id
        deletedAt
        activeSubscriptionsCount
      }
    }
  }

  query getInvoicesForTermination(
    $subscriptionId: ID!
    $invoiceType: [InvoiceTypeEnum!]
    $limit: Int
  ) {
    invoices(subscriptionId: $subscriptionId, invoiceType: $invoiceType, limit: $limit) {
      collection {
        id
        number
        currency
        invoiceType
        refundableAmountCents
        offsettableAmountCents
      }
    }
  }
`

export const TERMINATE_SUBSCRIPTION_SUBMIT_BUTTON_TEST_ID = 'terminate-subscription-submit-button'
const TERMINATE_SUBSCRIPTION_FORM_ID = 'terminate-subscription-form'
const LOADING_ERROR_MESSAGE = 'loading'

const terminateFormDefaultValues = {
  onTerminationInvoice: true,
  onTerminationCreditNote: OnTerminationCreditNoteEnum.Credit as OnTerminationCreditNoteEnum,
}

// Content component for Active subscriptions (manages invoice query + form fields)
interface TerminateContentProps {
  subscriptionId: string
  payInAdvance: boolean
  loadingRef: React.MutableRefObject<boolean>
}

const terminateContentDefaultProps: TerminateContentProps = {
  subscriptionId: '',
  payInAdvance: false,
  loadingRef: { current: false },
}

const TerminateContent = withForm({
  props: terminateContentDefaultProps,
  defaultValues: terminateFormDefaultValues,
  render: function Render({ form, subscriptionId, payInAdvance, loadingRef }) {
    const { translate } = useInternationalization()

    const { data: invoicesData, loading: invoiceLoading } = useGetInvoicesForTerminationQuery({
      variables: {
        subscriptionId,
        invoiceType: [InvoiceTypeEnum.Subscription],
        limit: 1,
      },
      skip: !payInAdvance,
    })

    const invoice = invoicesData?.invoices?.collection?.[0]
    const isCreditNoteOptionsLoading = payInAdvance && invoiceLoading
    const shouldShowCreditNoteOptions = payInAdvance && !invoiceLoading

    // Communicate loading state to parent
    useEffect(() => {
      loadingRef.current = isCreditNoteOptionsLoading
    }, [isCreditNoteOptionsLoading, loadingRef])

    const creditNoteOptions = useMemo(
      () =>
        [
          hasOffsettableAmount(invoice)
            ? {
                label: translate('text_1767883339943r32jn2ioyeu'),
                sublabel: translate('text_1768993189751mlil3uubnse'),
                value: OnTerminationCreditNoteEnum.Offset,
              }
            : undefined,
          {
            label: translate('text_1753198825180a94n1872cz4'),
            sublabel: translate('text_17531988251808so7qch9zrf'),
            value: OnTerminationCreditNoteEnum.Credit,
          },
          hasRefundableAmount(invoice)
            ? {
                label: translate('text_1753198825180jnk5xbdev57'),
                sublabel: translate('text_1753198825180bu4iaf2tczy'),
                value: OnTerminationCreditNoteEnum.Refund,
              }
            : undefined,
          {
            label: translate('text_1753198825180jfv0xkobkl5'),
            sublabel: translate('text_1753198825180k6hugot9xmt'),
            value: OnTerminationCreditNoteEnum.Skip,
          },
        ].filter((option) => !!option),
      [invoice, translate],
    )

    const defaultCreditNoteOption =
      creditNoteOptions[0]?.value ?? OnTerminationCreditNoteEnum.Credit

    // Update default credit note option when invoice data loads
    useEffect(() => {
      form.setFieldValue('onTerminationCreditNote', defaultCreditNoteOption)
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [defaultCreditNoteOption])

    return (
      <div className="flex flex-col gap-8 p-8">
        <div className="flex flex-col gap-4">
          <div>
            <Typography variant="bodyHl" color="grey700">
              {translate('text_62d904b97e690a881f2b867c')}
            </Typography>
            <Typography variant="caption">{translate('text_1753198825180dxhl10ooij3')}</Typography>
          </div>
          <form.AppField name="onTerminationInvoice">
            {(field) => (
              <field.SwitchField
                label={translate('text_1753198825180w91fhv7612n')}
                subLabel={translate('text_1753274319009dha80usx9zz')}
              />
            )}
          </form.AppField>
        </div>
        {isCreditNoteOptionsLoading && (
          <div className="flex flex-col gap-4">
            <div>
              <Skeleton variant="text" className="w-40" />
              <Skeleton variant="text" className="w-60" />
            </div>
            <div className="flex flex-col gap-3">
              <Skeleton variant="text" className="w-48" />
              <Skeleton variant="text" className="w-48" />
            </div>
          </div>
        )}
        {shouldShowCreditNoteOptions && (
          <div className="flex flex-col gap-4">
            <div>
              <Typography variant="bodyHl" color="grey700">
                {translate('text_1748341883774iypsrgem3hr')}
              </Typography>
              <Typography variant="caption">
                {translate('text_1753198825180qo474uj3p5f', {
                  invoiceNumber: invoice?.number,
                })}
              </Typography>
            </div>

            <form.AppField name="onTerminationCreditNote">
              {(field) => (
                <field.RadioGroupField optionLabelVariant="body" options={creditNoteOptions} />
              )}
            </form.AppField>
          </div>
        )}
      </div>
    )
  },
})

// Data passed when opening the dialog
interface TerminateCustomerSubscriptionDialogData {
  id: string
  name: string
  status: StatusTypeEnum
  payInAdvance: boolean
  callback?: (deletedAt?: string | null) => unknown
}

export const useTerminateCustomerSubscriptionDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const formDialog = useFormDialog()
  const { translate } = useInternationalization()
  const dataRef = useRef<TerminateCustomerSubscriptionDialogData | null>(null)
  const loadingRef = useRef(false)
  const successRef = useRef(false)

  const form = useAppForm({
    defaultValues: terminateFormDefaultValues,
  })

  const [terminate] = useTerminateCustomerSubscriptionMutation({
    onCompleted({ terminateSubscription }) {
      if (terminateSubscription) {
        successRef.current = true

        addToast({
          severity: 'success',
          translateKey: 'text_62d953aa13c166a6a24cbaf4',
        })

        dataRef.current?.callback?.(terminateSubscription?.customer?.deletedAt)
      }
    },
  })

  const handleTerminate = async (): Promise<DialogResult> => {
    successRef.current = false
    const data = dataRef.current

    if (loadingRef.current) {
      throw new Error(LOADING_ERROR_MESSAGE)
    }

    const values = form.state.values

    const payload: TerminateSubscriptionInput = {
      onTerminationInvoice: values.onTerminationInvoice
        ? OnTerminationInvoiceEnum.Generate
        : OnTerminationInvoiceEnum.Skip,
      onTerminationCreditNote: data?.payInAdvance ? values.onTerminationCreditNote : undefined,
      id: data?.id as string,
    }

    await terminate({ variables: { input: payload } })

    if (!successRef.current) {
      throw new Error('Termination failed')
    }

    return { reason: 'success' }
  }

  const onError = (error: Error) => {
    if (error.message === LOADING_ERROR_MESSAGE) return
  }

  const openTerminateCustomerSubscriptionDialog = (
    data: TerminateCustomerSubscriptionDialogData,
  ) => {
    dataRef.current = data
    form.reset()
    loadingRef.current = false

    if (data.status === StatusTypeEnum.Pending) {
      // Pending subscriptions: simple confirmation, no form fields
      centralizedDialog.open({
        title: translate('text_64a6d8cb9ed7d9007e7121ca'),
        description: translate('text_64a6d96f84411700a90dbf51', {
          subscriptionName: data.name,
        }),
        colorVariant: 'danger',
        actionText: translate('text_64a6d736c23125004817627f'),
        onAction: handleTerminate,
      })
    } else {
      // Active subscriptions: form fields for invoice/credit note options
      loadingRef.current = data.payInAdvance

      formDialog
        .open({
          title: translate('text_62d7f6178ec94cd09370e2f3'),
          description: data.payInAdvance
            ? translate('text_62d7f6178ec94cd09370e313')
            : translate('text_1753198825180e09v150qcko'),
          closeOnError: false,
          onError,
          children: (
            <TerminateContent
              form={form}
              subscriptionId={data.id}
              payInAdvance={data.payInAdvance}
              loadingRef={loadingRef}
            />
          ),
          mainAction: (
            <form.AppForm>
              <form.SubmitButton danger dataTest={TERMINATE_SUBSCRIPTION_SUBMIT_BUTTON_TEST_ID}>
                {translate('text_62d7f6178ec94cd09370e351')}
              </form.SubmitButton>
            </form.AppForm>
          ),
          form: {
            id: TERMINATE_SUBSCRIPTION_FORM_ID,
            submit: handleTerminate,
          },
        })
        .then((response) => {
          if (response.reason === 'close') {
            dataRef.current = null
          }
        })
    }
  }

  return { openTerminateCustomerSubscriptionDialog }
}
