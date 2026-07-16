import { FC, RefObject } from 'react'
import { generatePath, useSearchParams } from 'react-router-dom'

import { ActivityLogsTable as Table } from '~/components/activityLogs/ActivityLogsTable'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { ACTIVITY_LOG_ROUTE } from '~/components/developers/devtoolsRoutes'
import { ListSectionRef } from '~/components/developers/LogsLayout'
import { getCurrentBreakpoint } from '~/core/utils/getCurrentBreakpoint'
import { ActivityLogsQueryResult } from '~/generated/graphql'

interface ActivityLogTableProps {
  getActivityLogsResult: ActivityLogsQueryResult
  logListRef: RefObject<ListSectionRef>
}

export const ActivityLogTable: FC<ActivityLogTableProps> = ({
  getActivityLogsResult,
  logListRef,
}) => {
  const [searchParams] = useSearchParams()
  const { data, error, loading, fetchMore, refetch } = getActivityLogsResult

  return (
    <InfiniteScroll
      onBottom={async () => {
        const { currentPage = 0, totalPages = 0 } = data?.activityLogs?.metadata || {}

        if (currentPage < totalPages && !loading) {
          await fetchMore({
            variables: { page: currentPage + 1 },
          })
        }
      }}
    >
      <Table
        data={data?.activityLogs?.collection ?? []}
        isLoading={loading}
        error={error}
        refetch={refetch}
        onRowActionLink={({ activityId }) => {
          if (getCurrentBreakpoint() === 'sm') {
            logListRef.current?.updateView('forward')
          }

          const path = generatePath(ACTIVITY_LOG_ROUTE, {
            logId: activityId,
          })

          const query = searchParams.toString()
          const search = query ? `?${query}` : ''

          return `${path}${search}`
        }}
      />
    </InfiniteScroll>
  )
}
