import { FC, RefObject, useMemo } from 'react'
import { generatePath, useSearchParams } from 'react-router-dom'

import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Status, StatusType } from '~/components/designSystem/Status'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { variantByHTTPMethod } from '~/components/developers/apiLogs/mapping'
import { API_LOG_ROUTE } from '~/components/developers/devtoolsRoutes'
import { ListSectionRef } from '~/components/developers/LogsLayout'
import { getCurrentBreakpoint } from '~/core/utils/getCurrentBreakpoint'
import { GetApiLogsQueryResult } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useFormatterDateHelper } from '~/hooks/helpers/useFormatterDateHelper'

interface ApiLogsTableProps {
  getApiLogsResult: GetApiLogsQueryResult
  logListRef: RefObject<ListSectionRef>
}

export const ApiLogsTable: FC<ApiLogsTableProps> = ({ getApiLogsResult, logListRef }) => {
  const { translate } = useInternationalization()
  const { formattedDateTimeWithSecondsOrgaTZ } = useFormatterDateHelper()
  const [searchParams] = useSearchParams()

  const { data, error, loading, fetchMore, refetch } = getApiLogsResult

  const apiLogs = useMemo(() => {
    return (data?.apiLogs?.collection ?? []).map((log) => ({
      ...log,
      id: log.requestId,
    }))
  }, [data?.apiLogs?.collection])

  return (
    <InfiniteScroll
      onBottom={async () => {
        const { currentPage = 0, totalPages = 0 } = data?.apiLogs?.metadata || {}

        if (currentPage < totalPages && !loading) {
          await fetchMore({
            variables: { page: currentPage + 1 },
          })
        }
      }}
    >
      <Table
        name="api-logs"
        containerClassName="h-auto"
        containerSize={16}
        rowSize={48}
        data={apiLogs}
        hasError={!!error}
        isLoading={loading}
        onRowActionLink={({ id }) => {
          if (getCurrentBreakpoint() === 'sm') {
            logListRef.current?.updateView('forward')
          }

          const path = generatePath(API_LOG_ROUTE, { logId: id })
          const search = searchParams.toString()
          const fullPath = `${path}${search ? `?${search}` : ''}`

          return fullPath
        }}
        columns={[
          {
            title: translate('text_62865498824cc10126ab296f'),
            key: 'httpStatus',
            content: ({ httpStatus }) => {
              if (httpStatus && httpStatus >= 200 && httpStatus < 400) {
                return <Status type={StatusType.success} label={httpStatus} />
              }

              return <Status type={StatusType.danger} label={httpStatus ?? 500} />
            },
          },
          {
            title: translate('text_1749819996843c2c5f1j8e0n'),
            key: 'requestPath',
            maxSpace: true,
            content: ({ requestPath, httpMethod }) => (
              <Typography variant="captionCode">
                <Typography component="span" color={variantByHTTPMethod(httpMethod)}>
                  {httpMethod.toLocaleUpperCase()}
                </Typography>
                <Typography component="span" color="grey700" noWrap>
                  {' '}
                  {requestPath}
                </Typography>
              </Typography>
            ),
          },
          {
            title: translate('text_664cb90097bfa800e6efa3f5'),
            key: 'loggedAt',
            content: ({ loggedAt }) => (
              <Typography noWrap>{formattedDateTimeWithSecondsOrgaTZ(loggedAt)}</Typography>
            ),
          },
        ]}
        placeholder={{
          emptyState: {
            title: translate('text_1749819999030bazlbkouub6'),
            subtitle: translate('text_1749819999030hztj7r8w5rg'),
          },
          errorState: {
            title: translate('text_1747058197364dm3no1jnete'),
            subtitle: translate('text_63e27c56dfe64b846474ef3b'),
            buttonTitle: translate('text_63e27c56dfe64b846474ef3c'),
            buttonAction: () => refetch(),
          },
        }}
      />
    </InfiniteScroll>
  )
}
