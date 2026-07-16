import { gql } from '@apollo/client'
import { DateTime } from 'luxon'
import { useMemo } from 'react'
import { useSearchParams } from 'react-router-dom'

import { formatFiltersForSecurityLogsQuery } from '~/components/designSystem/Filters'
import { LagoApiError, useGetSecurityLogsQuery } from '~/generated/graphql'

import { SecurityLogs, SecurityLogWithId } from '../common/securityLogsTypes'

gql`
  fragment SecurityLogItem on SecurityLog {
    logId
    logEvent
    logType
    deviceInfo
    resources
    loggedAt
    userEmail
  }

  query getSecurityLogs(
    $page: Int
    $limit: Int
    $logEvents: [LogEventEnum!]
    $logTypes: [LogTypeEnum!]
    $fromDate: ISO8601DateTime
    $toDate: ISO8601DateTime!
    $userIds: [ID!]
  ) {
    securityLogs(
      page: $page
      limit: $limit
      logEvents: $logEvents
      logTypes: $logTypes
      fromDatetime: $fromDate
      toDatetime: $toDate
      userIds: $userIds
    ) {
      metadata {
        currentPage
        totalPages
      }
      collection {
        ...SecurityLogItem
      }
    }
  }
`

export const formatSecurityLogs = (securityLogs: SecurityLogs): Array<SecurityLogWithId> => {
  return securityLogs.map((securityLog) => ({ id: securityLog.logId, ...securityLog }))
}

export const useSecurityLogs = () => {
  const [searchParams] = useSearchParams()
  const defaultToDateTime = DateTime.now().endOf('day').toISO()

  const filtersForSecurityLogsQuery = useMemo(() => {
    const formattedFilters = formatFiltersForSecurityLogsQuery(searchParams)

    // The security logs query requires a toDate; fall back to the default when none is set.
    return {
      ...formattedFilters,
      toDate: formattedFilters.toDate ?? defaultToDateTime,
    }
  }, [defaultToDateTime, searchParams])

  const {
    data,
    loading: isLoadingSecurityLogs,
    fetchMore: fetchMoreSecurityLogs,
    refetch,
    error,
  } = useGetSecurityLogsQuery({
    variables: { limit: 20, ...filtersForSecurityLogsQuery },
    notifyOnNetworkStatusChange: true,
    context: {
      silentErrorCodes: [LagoApiError.FeatureUnavailable],
    },
  })

  const refetchSecurityLogs = async () => {
    await refetch({
      limit: 20,
      ...filtersForSecurityLogsQuery,
      page: 1,
    })
  }

  return {
    securityLogs: formatSecurityLogs(data?.securityLogs?.collection ?? []),
    securityLogsMetadata: data?.securityLogs?.metadata,
    isLoadingSecurityLogs,
    fetchMoreSecurityLogs,
    refetchSecurityLogs,
    securityLogsError: error,
    // We always have toDate in our filters
    hasFilters: Object.keys(filtersForSecurityLogsQuery).length > 1,
  }
}
