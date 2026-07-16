import { gql } from '@apollo/client'
import { Fragment } from 'react'
import { useParams } from 'react-router-dom'

import { CodeSnippet } from '~/components/CodeSnippet'
import { Button } from '~/components/designSystem/Button'
import { NavigationTab, TabManagedBy } from '~/components/designSystem/NavigationTab'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { useGetApiLogDetailsQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useFormatterDateHelper } from '~/hooks/helpers/useFormatterDateHelper'

gql`
  fragment ApiLogDetails on ApiLog {
    apiVersion
    client
    httpMethod
    httpStatus
    loggedAt
    requestBody
    requestId
    requestOrigin
    requestPath
    requestResponse
    apiKey {
      name
      value
    }
  }

  query getApiLogDetails($requestId: ID!) {
    apiLog(requestId: $requestId) {
      ...ApiLogDetails
    }
  }
`

export const ApiLogDetails = ({ goBack }: { goBack: () => void }) => {
  const { logId } = useParams<{ logId: string }>()
  const { translate } = useInternationalization()
  const { formattedDateTimeWithSecondsOrgaTZ } = useFormatterDateHelper()

  const { data, loading } = useGetApiLogDetailsQuery({
    variables: { requestId: logId || '' },
    skip: !logId,
  })

  const {
    apiKey,
    apiVersion,
    client,
    httpMethod,
    httpStatus,
    loggedAt,
    requestId,
    requestOrigin,
    requestPath,
  } = data?.apiLog ?? {}

  const requestBody = data?.apiLog?.requestBody ?? {}
  const responseBody = data?.apiLog?.requestResponse ?? {}

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
          <Typography variant="bodyHl" color="textSecondary">
            {requestPath}
          </Typography>
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
          <div className="grid grid-cols-[140px,_1fr] items-baseline gap-3 not-last:pb-12 not-last:shadow-b">
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

            {[
              [
                translate('text_1749819996843c2c5f1j8e0n'),
                `${httpMethod?.toLocaleUpperCase()} ${requestPath}`,
              ],
              [translate('text_174981999903061p5t158es0'), requestId],
              [
                translate('text_17473520702542eqnulj06zc'),
                formattedDateTimeWithSecondsOrgaTZ(loggedAt),
              ],
              [
                translate('text_645d071272418a14c1c76aa4'),
                apiKey?.name ? `${apiKey.name} - ${apiKey.value}` : apiKey?.value,
              ],
              [translate('text_1749819999030wkju3ix3cb9'), apiVersion],
              [translate('text_1749819999030rydiujmrsfq'), requestOrigin],
              [translate('text_1749819999030dyt6hu7nspj'), client],
              [translate('text_174981999903024ai3h557wm'), httpStatus],
            ]
              .filter(([label, value]) => !!label && !!value)
              .map(([label, value]) => (
                <Fragment key={label}>
                  <Typography key={label} className="pt-1" variant="caption">
                    {label}
                  </Typography>
                  <Typography
                    className="overflow-wrap-anywhere flex min-w-0 max-w-full"
                    color="grey700"
                  >
                    {value}
                  </Typography>
                </Fragment>
              ))}
          </div>

          {(Object.keys(requestBody).length > 0 || Object.keys(responseBody).length > 0) && (
            <div className="flex flex-col gap-4 pb-12">
              <Typography variant="subhead1" color="grey700">
                {translate('text_1729773655417k0y7nxt5c5j')}
              </Typography>

              <NavigationTab
                managedBy={TabManagedBy.INDEX}
                name="api-log-details-tabs"
                tabs={[
                  {
                    title: translate('text_17498224925954a8mk0enwdj'),
                    hidden: Object.keys(responseBody).length === 0,
                    component: (
                      <CodeSnippet
                        variant="minimal"
                        language="json"
                        code={JSON.stringify(responseBody, null, 2)}
                        displayHead={false}
                        canCopy
                      />
                    ),
                  },
                  {
                    title: translate('text_1749822492595ayr96w7ez17'),
                    hidden: Object.keys(requestBody).length === 0,
                    component: (
                      <CodeSnippet
                        variant="minimal"
                        language="json"
                        code={JSON.stringify(requestBody, null, 2)}
                        displayHead={false}
                        canCopy
                      />
                    ),
                  },
                ]}
              />
            </div>
          )}
        </div>
      )}
    </>
  )
}
