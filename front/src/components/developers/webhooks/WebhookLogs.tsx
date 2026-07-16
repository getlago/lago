import { gql } from '@apollo/client'
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef } from 'react'
import { generatePath, useParams, useSearchParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import {
  Filters,
  formatFiltersForWebhookLogsQuery,
  WebhookLogsAvailableFilters,
} from '~/components/designSystem/Filters'
import { WEBHOOK_LOGS_ROUTE } from '~/components/developers/devtoolsRoutes'
import { ListSectionRef, LogsLayout } from '~/components/developers/LogsLayout'
import { WebhookLogDetails } from '~/components/developers/webhooks/WebhookLogDetails'
import { WebhookLogTable } from '~/components/developers/webhooks/WebhookLogTable'
import { SearchInput } from '~/components/SearchInput'
import { WEBHOOK_LOGS_FILTER_PREFIX } from '~/core/constants/filters'
import { useNavigate } from '~/core/router'
import { getCurrentBreakpoint } from '~/core/utils/getCurrentBreakpoint'
import { useGetWebhookLogLazyQuery, WebhookLogFragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useDebouncedSearch } from '~/hooks/useDebouncedSearch'

gql`
  fragment WebhookLog on Webhook {
    id
    status
    webhookType
    createdAt
    updatedAt
    endpoint
  }

  query getWebhookLog(
    $page: Int
    $limit: Int
    $webhookEndpointId: String!
    $statuses: [WebhookStatusEnum!]
    $eventTypes: [String!]
    $httpStatuses: [String!]
    $fromDate: ISO8601DateTime
    $toDate: ISO8601DateTime
    $searchTerm: String
  ) {
    webhooks(
      page: $page
      limit: $limit
      webhookEndpointId: $webhookEndpointId
      statuses: $statuses
      eventTypes: $eventTypes
      httpStatuses: $httpStatuses
      fromDate: $fromDate
      toDate: $toDate
      searchTerm: $searchTerm
    ) {
      metadata {
        currentPage
        totalPages
      }
      collection {
        id
        ...WebhookLog
      }
    }
  }
`

// Test ID constants
export const WEBHOOK_LOGS_CONTAINER_TEST_ID = 'webhook-logs-container'
export const WEBHOOK_LOGS_RELOAD_BUTTON_TEST_ID = 'webhook-logs-reload-button'
export const WEBHOOK_LOGS_SEARCH_INPUT_TEST_ID = 'webhook-logs-search-input'

type WebhookLogsProps = {
  webhookId: string
}

export const WebhookLogs = ({ webhookId }: WebhookLogsProps) => {
  const { logId } = useParams<{ webhookId: string; logId?: string }>()
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()

  const logListRef = useRef<ListSectionRef>(null)

  const searchParamsString = searchParams.toString()

  const filtersForWebhookLogsQuery = useMemo(() => {
    return formatFiltersForWebhookLogsQuery(new URLSearchParams(searchParamsString))
  }, [searchParamsString])

  const queryVariables = useMemo(
    () => ({
      webhookEndpointId: webhookId,
      limit: 20,
      ...filtersForWebhookLogsQuery,
    }),
    [webhookId, filtersForWebhookLogsQuery],
  )

  const [getWebhookLogs, getWebhookLogsResult] = useGetWebhookLogLazyQuery({
    variables: queryVariables,
    notifyOnNetworkStatusChange: true,
  })

  const { data, loading } = getWebhookLogsResult

  const { debouncedSearch, isLoading: isSearchLoading } = useDebouncedSearch(
    getWebhookLogs,
    loading,
  )

  // Re-fetch when filter variables change (after the initial mount fetch handled by useDebouncedSearch)
  const hasInitiallyFetched = useRef(false)

  useEffect(() => {
    if (!hasInitiallyFetched.current) {
      hasInitiallyFetched.current = true
      return
    }

    getWebhookLogs()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [queryVariables])

  // Refetch with fresh filters to avoid stale toDate from the memoized query variables.
  // Standard refetch() reuses variables from the initial execution, which includes a frozen toDate.
  const refetchWithFreshFilters = useCallback(async () => {
    const freshFilters = formatFiltersForWebhookLogsQuery(
      new URLSearchParams(searchParams.toString()),
    )

    return getWebhookLogs({
      variables: { ...queryVariables, ...freshFilters },
      fetchPolicy: 'network-only',
    })
  }, [getWebhookLogs, queryVariables, searchParams])

  const navigateToFirstLog = useCallback(
    (logCollection?: WebhookLogFragment[], currentSearchParams?: URLSearchParams) => {
      if (logCollection?.length) {
        const firstLog = logCollection[0]

        if (firstLog && getCurrentBreakpoint() !== 'sm') {
          navigate(
            {
              pathname: generatePath(WEBHOOK_LOGS_ROUTE, { webhookId, logId: firstLog.id }),
              search: currentSearchParams?.toString(),
            },
            {
              replace: true,
            },
          )
        }
      }
    },
    [navigate, webhookId],
  )

  // If no logId is provided in params, navigate to the first log
  useEffect(() => {
    if (!logId) {
      navigateToFirstLog(data?.webhooks?.collection, searchParams)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [data?.webhooks.collection, logId])

  // The table should highlight the selected row when the logId is provided in params
  useLayoutEffect(() => {
    if (logId && logListRef.current) {
      logListRef.current.setActiveRow(logId)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [logId, logListRef.current])

  const shouldDisplayLogDetails = !!logId && !!data?.webhooks.collection.length

  return (
    <div
      className="flex h-full flex-col not-last-child:shadow-b"
      data-test={WEBHOOK_LOGS_CONTAINER_TEST_ID}
    >
      <LogsLayout.CTASection className="min-h-[70px]">
        <SearchInput
          onChange={debouncedSearch}
          placeholder={translate('text_1746622271766lr6wf4y0ppn')}
          data-test={WEBHOOK_LOGS_SEARCH_INPUT_TEST_ID}
        />

        <div>
          <Filters.Provider
            filtersNamePrefix={WEBHOOK_LOGS_FILTER_PREFIX}
            availableFilters={WebhookLogsAvailableFilters}
            displayInDialog
          >
            <Filters.Component />
          </Filters.Provider>
        </div>

        <div className="h-8 w-px shadow-r" />

        <Button
          startIcon="reload"
          size="small"
          variant="quaternary"
          data-test={WEBHOOK_LOGS_RELOAD_BUTTON_TEST_ID}
          onClick={async () => {
            const result = await refetchWithFreshFilters()

            navigateToFirstLog(result.data?.webhooks?.collection, searchParams)
          }}
        >
          {translate('text_1738748043939zqoqzz350yj')}
        </Button>
      </LogsLayout.CTASection>
      <LogsLayout.ListSection
        ref={logListRef}
        leftSide={
          <WebhookLogTable
            getWebhookLogsResult={getWebhookLogsResult}
            logListRef={logListRef}
            isLoading={isSearchLoading}
          />
        }
        rightSide={<WebhookLogDetails goBack={() => logListRef.current?.updateView('backward')} />}
        shouldDisplayRightSide={shouldDisplayLogDetails}
      />
    </div>
  )
}
