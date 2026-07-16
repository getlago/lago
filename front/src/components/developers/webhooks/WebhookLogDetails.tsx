import { gql } from '@apollo/client'
import { Fragment, useEffect, useRef } from 'react'
import { useParams } from 'react-router-dom'

import { CodeSnippet } from '~/components/CodeSnippet'
import { Button } from '~/components/designSystem/Button'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Status } from '~/components/designSystem/Status'
import { Typography } from '~/components/designSystem/Typography'
import {
  formatWebhookResponseLabel,
  statusWebhookMapping,
} from '~/components/developers/webhooks/utils'
import { addToast } from '~/core/apolloClient'
import { pollUntilCondition } from '~/core/utils/pollUntilCondition'
import {
  LagoApiError,
  useGetSingleWebhookLogQuery,
  useRetryWebhookMutation,
  WebhookStatusEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useFormatterDateHelper } from '~/hooks/helpers/useFormatterDateHelper'

export const WEBHOOK_RETRY_BUTTON_TEST_ID = 'webhook-retry-button'

gql`
  fragment WebhookLogDetails on Webhook {
    id
    webhookType
    status
    payload
    response
    httpStatus
    endpoint
    retries
    updatedAt
  }

  mutation retryWebhook($input: RetryWebhookInput!) {
    retryWebhook(input: $input) {
      id
    }
  }

  query getSingleWebhookLog($id: ID!) {
    webhook(id: $id) {
      id
      ...WebhookLogDetails
    }
  }
`

export const WebhookLogDetails = ({ goBack }: { goBack: () => void }) => {
  const { logId } = useParams<{ webhookId: string; logId: string }>()
  const { formattedDateTimeWithSecondsOrgaTZ } = useFormatterDateHelper()
  const { translate } = useInternationalization()
  const abortControllerRef = useRef<AbortController | null>(null)

  // Abort on unmount to stop retry if we leave the developer panel
  useEffect(() => {
    return () => {
      abortControllerRef.current?.abort()
    }
  }, [])

  const { data, loading, refetch } = useGetSingleWebhookLogQuery({
    variables: { id: logId || '' },
    skip: !logId,
  })

  const { id, webhookType, updatedAt, endpoint, retries, response, status, httpStatus, payload } =
    data?.webhook || {}

  const [retry] = useRetryWebhookMutation({
    variables: { input: { id: id || '' } },
    context: { silentErrorCodes: [LagoApiError.IsSucceeded] },
    refetchQueries: ['getSingleWebhookLog'],
    async onCompleted({ retryWebhook }) {
      if (!!retryWebhook) {
        addToast({
          severity: 'success',
          translateKey: 'text_63f79ddae2e0b1892bb4955c',
        })
      }
    },
    onError: ({ graphQLErrors }) => {
      const isAlreadySucceeded = graphQLErrors.some(
        (error) => error.extensions?.code === LagoApiError.IsSucceeded,
      )

      if (isAlreadySucceeded) {
        addToast({
          severity: 'info',
          message: translate('text_1738502636498nhm8cuzx946'),
        })
      } else {
        addToast({
          severity: 'danger',
          translateKey: 'text_62b31e1f6a5b8b1b745ece48',
        })
      }
    },
  })

  const hasError = status === WebhookStatusEnum.Failed

  // Launch the webhook retry and then wait for the status to be other than 'PENDING'
  // We check every second if the status has changed or not. Until then, the retry button is disabled
  const retryWebhookAndWait = async () => {
    const { data: retryData } = await retry()

    // Only poll if the retry was accepted by the backend
    if (!retryData?.retryWebhook) {
      return
    }

    abortControllerRef.current = new AbortController()

    await pollUntilCondition(
      async () => {
        const { data: refreshedData } = await refetch()

        return refreshedData?.webhook?.status
      },
      (webhookStatus) => webhookStatus !== WebhookStatusEnum.Pending,
      { maxAttempts: 3, pollInterval: 1000, signal: abortControllerRef.current.signal },
    )
  }

  return (
    <>
      <Typography
        className="hidden min-h-14 items-center justify-between px-4 py-2 shadow-b md:flex"
        variant="bodyHl"
        color="textSecondary"
      >
        {loading ? (
          <Skeleton variant="text" textVariant="bodyHl" className="w-30" />
        ) : (
          <>
            {webhookType}
            {hasError && (
              <Button
                variant="quaternary"
                onClick={async () => await retryWebhookAndWait()}
                data-test={WEBHOOK_RETRY_BUTTON_TEST_ID}
              >
                {translate('text_63e27c56dfe64b846474efa3')}
              </Button>
            )}
          </>
        )}
      </Typography>

      {loading && (
        <div className="flex flex-col gap-4 p-4">
          <Skeleton variant="text" textVariant="subhead1" className="w-40" />
          <div className="grid grid-cols-[140px,_1fr] items-baseline gap-x-8 gap-y-3">
            {[...Array(3)].map((_, index) => (
              <Fragment key={index}>
                <Skeleton variant="text" textVariant="caption" className="w-20" />
                <Skeleton variant="text" textVariant="caption" className="w-full" />
              </Fragment>
            ))}
          </div>
        </div>
      )}

      {!loading && (
        <div className="flex flex-col gap-12 p-4">
          <div className="grid grid-cols-[140px,_1fr] items-baseline gap-3 pb-12 shadow-b">
            <div className="col-span-2 flex items-center justify-between">
              <Typography variant="subhead1" color="grey700">
                {translate('text_174662372967481i3t20hzfv')}
              </Typography>
              <Button
                icon="close"
                variant="quaternary"
                size="small"
                onClick={() => goBack()}
                className="md:hidden"
              />
            </div>

            <Typography className="pt-1" variant="caption">
              {translate('text_63e27c56dfe64b846474ef72')}
            </Typography>
            <div className="flex items-center gap-2">
              <Typography
                className="overflow-wrap-anywhere flex min-w-0 max-w-full"
                color="grey700"
              >
                {webhookType}
              </Typography>
              <Status {...statusWebhookMapping(status)} />
            </div>

            <Typography className="pt-1" variant="caption">
              {translate('text_63e27c56dfe64b846474ef70')}
            </Typography>
            <Typography className="overflow-wrap-anywhere flex min-w-0 max-w-full" color="grey700">
              {id}
            </Typography>

            <Typography className="pt-1" variant="caption">
              {translate('text_63e27c56dfe64b846474ef6c')}
            </Typography>
            <Typography className="overflow-wrap-anywhere flex min-w-0 max-w-full" color="grey700">
              {formattedDateTimeWithSecondsOrgaTZ(updatedAt)}
            </Typography>

            <Typography className="pt-1" variant="caption">
              {translate('text_63e27c56dfe64b846474ef6e')}
            </Typography>
            <Typography className="overflow-wrap-anywhere flex min-w-0 max-w-full" color="grey700">
              {endpoint}
            </Typography>

            {httpStatus && (
              <>
                <Typography className="pt-1" variant="caption">
                  {translate('text_63e27c56dfe64b846474ef74')}
                </Typography>
                <Typography
                  className="overflow-wrap-anywhere flex min-w-0 max-w-full"
                  color="grey700"
                >
                  {formatWebhookResponseLabel(httpStatus, status)}
                </Typography>
              </>
            )}

            {!!retries && retries > 0 && (
              <>
                <Typography className="pt-1" variant="caption">
                  {translate('text_63e27c56dfe64b846474efb2')}
                </Typography>
                <Typography
                  className="overflow-wrap-anywhere flex min-w-0 max-w-full"
                  color="grey700"
                >
                  {retries}
                </Typography>
              </>
            )}
          </div>

          {response && hasError && (
            <div className="flex flex-col gap-4 pb-12 shadow-b">
              <Typography variant="subhead1" color="grey700">
                {translate('text_1746623729674lo13y0oatk9')}
              </Typography>
              <CodeSnippet
                variant="minimal"
                language="json"
                code={response}
                canCopy
                displayHead={false}
              />
            </div>
          )}

          {Object.keys(payload ?? {}).length > 0 && (
            <div className="flex flex-col gap-4 pb-12">
              <Typography variant="subhead1" color="grey700">
                {translate('text_1746623729674wq0tach0cop')}
              </Typography>
              <CodeSnippet
                variant="minimal"
                language="json"
                code={JSON.stringify(JSON.parse(payload || ''), null, 2)}
                canCopy
                displayHead={false}
              />
            </div>
          )}
        </div>
      )}
    </>
  )
}
