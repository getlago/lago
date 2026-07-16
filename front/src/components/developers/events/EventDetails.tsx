import { gql } from '@apollo/client'
import { Fragment } from 'react'
import { useParams } from 'react-router-dom'

import { CodeSnippet } from '~/components/CodeSnippet'
import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { TimezoneDate } from '~/components/TimezoneDate'
import { DateFormat, TimeFormat } from '~/core/timezone/utils'
import { useGetSingleEventQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment EventDetails on Event {
    id
    code
    transactionId
    timestamp
    receivedAt
    payload
    billableMetricName
    matchBillableMetric
    matchCustomField
    apiClient
    ipAddress
    externalSubscriptionId
    customerTimezone
  }

  query getSingleEvent($transactionId: ID!) {
    event(transactionId: $transactionId) {
      id
      ...EventDetails
    }
  }
`

const dateFormatOptions = {
  formatTime: TimeFormat.TIME_24_WITH_SECONDS,
  formatDate: DateFormat.DATE_MED,
}

export const EventDetails = ({ goBack }: { goBack: () => void }) => {
  const { '*': eventId } = useParams<{ '*': string }>()
  const { translate } = useInternationalization()

  const { data, loading } = useGetSingleEventQuery({
    variables: { transactionId: eventId || '' },
    skip: !eventId,
  })

  const {
    billableMetricName,
    timestamp,
    receivedAt,
    payload,
    transactionId,
    apiClient,
    code,
    ipAddress,
    matchBillableMetric,
    matchCustomField,
    externalSubscriptionId,
    customerTimezone,
  } = data?.event || {}

  return (
    <>
      <Typography
        className="hidden min-h-14 items-center justify-between px-4 py-2 shadow-b md:flex"
        variant="bodyHl"
        color="textSecondary"
      >
        {loading ? <Skeleton variant="text" textVariant="bodyHl" className="w-30" /> : code}
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
                {translate('text_63ebba5f5160e26242c48bd2')}
              </Typography>
              <Button
                icon="close"
                variant="quaternary"
                size="small"
                onClick={() => goBack()}
                className="md:hidden"
              />
            </div>

            {!matchBillableMetric && (
              <div className="col-span-2">
                <Alert type="warning">{translate('text_6298bd525e359200d5ea01b7')}</Alert>
              </div>
            )}

            {!matchCustomField && (
              <div className="col-span-2">
                <Alert type="warning">{translate('text_6298bd525e359200d5ea0197')}</Alert>
              </div>
            )}

            <Typography className="pt-1" variant="caption">
              {translate('text_6298bd525e359200d5ea01da')}
            </Typography>
            <Typography className="overflow-wrap-anywhere flex min-w-0 max-w-full" color="grey700">
              {billableMetricName}
            </Typography>

            <Typography className="pt-1" variant="caption">
              {translate('text_6298bd525e359200d5ea01c1')}
            </Typography>
            <Typography className="overflow-wrap-anywhere flex min-w-0 max-w-full" color="grey700">
              {code}
            </Typography>

            <Typography className="pt-1" variant="caption">
              {translate('text_6298bd525e359200d5ea01f2')}
            </Typography>
            <Typography className="overflow-wrap-anywhere flex min-w-0 max-w-full" color="grey700">
              {transactionId}
            </Typography>

            <Typography className="pt-1" variant="caption">
              {translate('text_62e0feac0a543924c8f67ae5')}
            </Typography>
            <Typography className="overflow-wrap-anywhere flex min-w-0 max-w-full" color="grey700">
              {externalSubscriptionId}
            </Typography>

            <Typography className="pt-1" variant="caption">
              {translate('text_1730132579304cmiwba11ha6')}
            </Typography>
            <TimezoneDate
              className="overflow-wrap-anywhere flex min-w-0 max-w-full"
              date={receivedAt}
              customerTimezone={customerTimezone}
              mainTimezone="utc0"
              mainDateFormat={dateFormatOptions}
              showFullDateTime={true}
              position="top-start"
            />

            <Typography className="pt-1" variant="caption">
              {translate('text_6298bd525e359200d5ea018f')}
            </Typography>
            <TimezoneDate
              className="overflow-wrap-anywhere flex min-w-0 max-w-full"
              date={timestamp}
              customerTimezone={customerTimezone}
              mainTimezone="utc0"
              mainDateFormat={dateFormatOptions}
              showFullDateTime={true}
              position="top-start"
            />

            {!!ipAddress && (
              <>
                <Typography className="pt-1" variant="caption">
                  {translate('text_6298bd525e359200d5ea020a')}
                </Typography>
                <Typography
                  className="overflow-wrap-anywhere flex min-w-0 max-w-full"
                  color="grey700"
                >
                  {ipAddress}
                </Typography>
              </>
            )}

            {!!apiClient && (
              <>
                <Typography className="pt-1" variant="caption">
                  {translate('text_6298bd525e359200d5ea0222')}
                </Typography>
                <Typography
                  className="overflow-wrap-anywhere flex min-w-0 max-w-full"
                  color="grey700"
                >
                  {apiClient}
                </Typography>
              </>
            )}
          </div>

          <div className="flex flex-col gap-4 pb-12">
            <Typography variant="subhead1" color="grey700">
              {translate('text_1746623729674wq0tach0cop')}
            </Typography>
            <CodeSnippet
              variant="minimal"
              language="json"
              code={JSON.stringify(payload, null, 2)}
              displayHead={false}
              canCopy
            />
          </div>
        </div>
      )}
    </>
  )
}
