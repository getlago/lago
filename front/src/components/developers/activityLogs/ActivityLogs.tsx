import { gql } from '@apollo/client'
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef } from 'react'
import { generatePath, useParams, useSearchParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import {
  ActivityLogsAvailableFilters,
  Filters,
  formatFiltersForActivityLogsQuery,
} from '~/components/designSystem/Filters'
import { Typography } from '~/components/designSystem/Typography'
import { ActivityLogDetails } from '~/components/developers/activityLogs/ActivityLogDetails'
import { ActivityLogTable } from '~/components/developers/activityLogs/ActivityLogTable'
import { ACTIVITY_LOG_ROUTE } from '~/components/developers/devtoolsRoutes'
import { ListSectionRef, LogsLayout } from '~/components/developers/LogsLayout'
import { ACTIVITY_LOG_FILTER_PREFIX } from '~/core/constants/filters'
import { useNavigate } from '~/core/router'
import { getCurrentBreakpoint } from '~/core/utils/getCurrentBreakpoint'
import { ActivityItemFragment, LagoApiError, useActivityLogsQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment ActivityItem on ActivityLog {
    activityId
    activityType
    activityObject
    externalCustomerId
    externalSubscriptionId
    loggedAt
  }

  query activityLogs(
    $page: Int
    $limit: Int
    $activityIds: [String!]
    $activitySources: [ActivitySourceEnum!]
    $activityTypes: [ActivityTypeEnum!]
    $apiKeyIds: [String!]
    $externalCustomerId: String
    $externalSubscriptionId: String
    $fromDate: ISO8601DateTime
    $resourceIds: [String!]
    $resourceTypes: [ResourceTypeEnum!]
    $toDate: ISO8601DateTime
    $userEmails: [String!]
  ) {
    activityLogs(
      page: $page
      limit: $limit
      activityIds: $activityIds
      activitySources: $activitySources
      activityTypes: $activityTypes
      apiKeyIds: $apiKeyIds
      externalCustomerId: $externalCustomerId
      externalSubscriptionId: $externalSubscriptionId
      fromDatetime: $fromDate
      resourceIds: $resourceIds
      resourceTypes: $resourceTypes
      toDatetime: $toDate
      userEmails: $userEmails
    ) {
      collection {
        ...ActivityItem
      }
      metadata {
        currentPage
        totalPages
      }
    }
  }
`

export const ActivityLogs = () => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { logId } = useParams<{ logId: string }>()
  const [searchParams] = useSearchParams()
  const logListRef = useRef<ListSectionRef>(null)

  const filtersForActivityLogsQuery = useMemo(() => {
    return formatFiltersForActivityLogsQuery(searchParams)
  }, [searchParams])

  const getActivityLogsResult = useActivityLogsQuery({
    variables: { limit: 20, ...filtersForActivityLogsQuery },
    notifyOnNetworkStatusChange: true,
    context: {
      silentErrorCodes: [LagoApiError.FeatureUnavailable],
    },
  })

  const { data, loading, refetch } = getActivityLogsResult

  const navigateToFirstLog = useCallback(
    (logCollection?: ActivityItemFragment[], currentSearchParams?: URLSearchParams) => {
      if (logCollection?.length) {
        const firstLog = logCollection[0]

        if (firstLog && getCurrentBreakpoint() !== 'sm') {
          const path = generatePath(ACTIVITY_LOG_ROUTE, { logId: firstLog.activityId })
          const query = currentSearchParams?.toString()
          const search = query ? `?${query}` : ''

          navigate(`${path}${search}`, {
            replace: true,
          })
        }
      }
    },
    [navigate],
  )

  useEffect(() => {
    if (!logId) {
      navigateToFirstLog(data?.activityLogs?.collection, searchParams)
    } else {
      const existingLog = data?.activityLogs?.collection.find((log) => log.activityId === logId)

      if (!existingLog) {
        navigateToFirstLog(data?.activityLogs?.collection, searchParams)
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [data?.activityLogs?.collection, logId, searchParams])

  // The table should highlight the selected row when the logId is provided in params
  useLayoutEffect(() => {
    if (logId) {
      logListRef.current?.setActiveRow(logId)
    }
  }, [logId])

  const shouldDisplayLogDetails = !!logId && !!data?.activityLogs?.collection.length

  return (
    <div className="flex h-full flex-col not-last-child:shadow-b">
      <Typography variant="headline" className="p-4">
        {translate('text_1747314141347qq6rasuxisl')}
      </Typography>

      <LogsLayout.CTASection>
        <div>
          <Filters.Provider
            displayInDialog
            filtersNamePrefix={ACTIVITY_LOG_FILTER_PREFIX}
            availableFilters={ActivityLogsAvailableFilters}
          >
            <Filters.Component />
          </Filters.Provider>
        </div>

        <div className="h-8 w-px shadow-r" />

        <Button
          variant="quaternary"
          size="small"
          startIcon="reload"
          loading={loading}
          onClick={async () => {
            const result = await refetch({
              ...formatFiltersForActivityLogsQuery(searchParams),
              page: 1,
            })

            navigateToFirstLog(result.data?.activityLogs?.collection, searchParams)
          }}
        >
          {translate('text_1738748043939zqoqzz350yj')}
        </Button>
      </LogsLayout.CTASection>
      <LogsLayout.ListSection
        ref={logListRef}
        leftSide={
          <ActivityLogTable getActivityLogsResult={getActivityLogsResult} logListRef={logListRef} />
        }
        rightSide={<ActivityLogDetails goBack={() => logListRef.current?.updateView('backward')} />}
        shouldDisplayRightSide={shouldDisplayLogDetails}
      />
    </div>
  )
}
